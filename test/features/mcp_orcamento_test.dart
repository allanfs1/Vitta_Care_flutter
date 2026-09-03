import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/modules/mcp/mcp_server.dart';
import 'package:vitta_app/core/modules/mcp/mcp_tool.dart';

/// Travas de orçamento do MCP e do agente.
///
/// O `limite` de uma listagem vem dos argumentos da tool — ou seja, **do LLM**.
/// Tudo que o modelo controla e entra no contexto precisa de teto, porque o
/// resultado é reenviado a cada rodada seguinte do loop de ferramentas.
void main() {
  final ctx = McpContext(defaultClinicaId: 'c1');

  group('Teto do limite de listagem', () {
    test('valor do LLM acima do teto é cortado', () {
      expect(ctx.limit(50000), McpContext.maxLimit);
      expect(ctx.limit(201), McpContext.maxLimit);
      expect(ctx.limit('99999'), McpContext.maxLimit);
    });

    test('valor negativo ou zero vira 1, não explode', () {
      // `Iterable.take(-5)` lança RangeError — o clamp evita.
      expect(ctx.limit(-5), 1);
      expect(ctx.limit(0), 1);
      expect(ctx.limit('-3'), 1);
    });

    test('valor razoável passa intacto', () {
      expect(ctx.limit(10), 10);
      expect(ctx.limit(200), 200);
      expect(ctx.limit('25'), 25);
    });

    test('ausente ou inválido cai no padrão', () {
      expect(ctx.limit(), McpContext.defaultLimit);
      expect(ctx.limit(null), McpContext.defaultLimit);
      expect(ctx.limit('abc'), McpContext.defaultLimit);
    });

    test('o padrão está dentro do teto', () {
      expect(McpContext.defaultLimit, lessThanOrEqualTo(McpContext.maxLimit));
    });
  });

  group('Serialização das tools', () {
    test('ok() devolve JSON compacto — indentação é token pago', () {
      final r = ok({
        'itens': [
          {'id': 'a1', 'nome': 'Paciente Um', 'risco': 'baixo'},
          {'id': 'a2', 'nome': 'Paciente Dois', 'risco': 'alto'},
        ],
      });

      expect(r.text.contains('\n'), isFalse,
          reason: 'sem quebra de linha: o consumidor é um LLM');
      expect(r.text.contains('  '), isFalse, reason: 'sem indentação');
      expect(r.isError, isFalse);

      // Continua sendo JSON válido.
      final v = jsonDecode(r.text) as Map<String, dynamic>;
      expect((v['itens'] as List).length, 2);
    });

    test('o formato compacto economiza sobre o indentado', () {
      final dados = {
        'agendamentos': [
          for (var i = 0; i < 50; i++)
            {
              'id': 'ag_$i',
              'paciente': 'Paciente $i',
              'medico': 'Dr. Fulano',
              'status': 'confirmado',
              'risco': 'baixo',
            },
        ],
      };

      final compacto = ok(dados).text.length;
      final indentado =
          const JsonEncoder.withIndent('  ').convert(dados).length;

      expect(compacto, lessThan(indentado));
      // O ganho é grande o bastante para valer a mudança.
      expect(compacto / indentado, lessThan(0.75),
          reason: 'compacto=$compacto indentado=$indentado');
    });
  });

  group('Catálogo de ferramentas', () {
    test('todo spec tem nome e descrição não vazios', () {
      final specs = createMcpServer(defaultClinicaId: 'c1').listToolSpecs();
      expect(specs, isNotEmpty);

      for (final s in specs) {
        final fn = (s['function'] as Map?) ?? s;
        expect((fn['name'] ?? '').toString(), isNotEmpty);
        expect((fn['description'] ?? '').toString(), isNotEmpty,
            reason: 'tool ${fn['name']} sem descrição — o modelo escolhe '
                'ferramenta pela descrição');
      }
    });

    test('não há nome de ferramenta duplicado', () {
      final specs = createMcpServer(defaultClinicaId: 'c1').listToolSpecs();
      final nomes = specs
          .map((s) => (((s['function'] as Map?) ?? s)['name']).toString())
          .toList();
      expect(nomes.toSet().length, nomes.length,
          reason: 'nome duplicado faz o modelo chamar a tool errada');
    });
  });
}
