import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/modules/mcp/mcp_server.dart';
import 'package:vitta_app/core/modules/mcp/mcp_tool.dart';

// Isolamento multi-tenant do servidor MCP — a superfície pela qual a IA lê e
// grava no banco (~75 ferramentas).
//
// `McpContext` tinha uma clínica de produção fixa (`JuhdNt7NG3GYOFKOKOXP`) como
// fallback de `defaultClinicaId`. Como TODA a barreira de isolamento se ancora
// nesse campo, um contexto criado sem clínica — o que acontece nos primeiros
// frames de cada boot, enquanto `tb_clinica` não respondeu — fazia a IA operar
// integralmente sobre os dados de outra clínica.
//
// Agora o contexto sem clínica é fail-closed: recusa em vez de adivinhar.
void main() {
  group('contexto sem clínica resolvida', () {
    final ctx = McpContext();

    test('não inventa uma clínica de fallback', () {
      expect(ctx.temClinica, isFalse);
      expect(ctx.defaultClinicaId, '');
    });

    test('pedir a clínica lança em vez de devolver uma arbitrária', () {
      expect(() => ctx.clinicaId(), throwsA(isA<McpSemClinica>()));
    });

    test('o LLM não consegue forçar uma clínica pelos argumentos', () {
      expect(() => ctx.clinicaId('OutraClinicaQualquer'),
          throwsA(isA<McpSemClinica>()));
    });

    test('nenhum documento passa pela barreira de tenant', () {
      const doc = {'clinicaId': 'AlgumaClinica', 'nome': 'x'};
      expect(ctx.belongsToClinic(doc), isFalse);
      expect(ctx.isForeignClinic(doc), isTrue,
          reason: 'sem clínica resolvida, todo documento é de terceiros');
    });

    test('toda tool recusa antes de abrir conexão com o banco', () async {
      final servidor = createMcpServer(defaultClinicaId: '');
      expect(servidor.toolNames, isNotEmpty);

      // Amostra por grupo: leitura, escrita no Cérebro e escrita operacional.
      for (final nome in [
        'cerebro_listar',
        'cerebro_escrever',
        'cerebro_buscar',
      ]) {
        final r = await servidor.callTool(nome, {});
        expect(r.isError, isTrue, reason: '$nome deveria recusar');
        expect(r.text, contains('clínica'),
            reason: '$nome deve recusar por falta de clínica, não por outro '
                'erro que aconteceu antes');
      }
    });

    test('todas as ~75 ferramentas recusam sem exceção', () async {
      final servidor = createMcpServer(defaultClinicaId: '');
      for (final nome in servidor.toolNames) {
        final r = await servidor.callTool(nome, {});
        expect(r.isError, isTrue, reason: '$nome operou sem clínica');
      }
    });
  });

  group('contexto com clínica resolvida', () {
    final ctx = McpContext(defaultClinicaId: 'ClinicaDoUsuario');

    test('opera na clínica do usuário', () {
      expect(ctx.temClinica, isTrue);
      expect(ctx.clinicaId(), 'ClinicaDoUsuario');
    });

    test('o LOCK ignora a clínica sugerida pelo LLM', () {
      expect(ctx.clinicaId('ClinicaAlheia'), 'ClinicaDoUsuario');
    });

    test('separa documento próprio de documento alheio', () {
      expect(ctx.belongsToClinic({'clinicaId': 'ClinicaDoUsuario'}), isTrue);
      expect(ctx.isForeignClinic({'clinicaId': 'ClinicaDoUsuario'}), isFalse);
      expect(ctx.isForeignClinic({'clinicaId': 'ClinicaAlheia'}), isTrue);
    });

    test('documento sem campo de clínica passa (coleção global)', () {
      expect(ctx.isForeignClinic({'nome': 'plano basico'}), isFalse);
    });
  });
}
