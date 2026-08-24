import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/utils/validators.dart';

/// Testes de segurança:
/// 1. Política de senha forte é realmente aplicada (PU-05).
/// 2. Validação de CPF rejeita entradas forjadas (integridade de dados).
/// 3. Nenhum segredo (chave de IA / token Z-API) está embarcado no código cliente.
void main() {
  group('Política de senha (PU-05)', () {
    test('bloqueia senhas fracas comuns', () {
      for (final weak in ['123456', 'password', 'Senha123', 'aaaaaaaa', 'Abc@1']) {
        expect(Validators.password(weak), isNotNull, reason: 'deveria rejeitar "$weak"');
      }
    });
    test('aceita apenas senha que cumpre todos os critérios', () {
      expect(Validators.password('F0rte@Senha'), isNull);
    });
  });

  group('Integridade de CPF', () {
    test('rejeita CPF com dígito verificador adulterado', () {
      expect(Validators.cpf('529.982.247-00'), isNotNull);
    });
  });

  group('Sem segredos embarcados no cliente (lib/)', () {
    // Trechos sensíveis que NÃO devem aparecer no código compilado para o cliente.
    const forbidden = [
      '2pnTQxv7hCLn1j5mJQ6JT6F3LL5zIhPPaZ2qqx6ihwWDqblTOpVeJQQJ', // chave Azure AI
    ];

    test('nenhum arquivo .dart contém chaves/credenciais conhecidas', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), true, reason: 'execute a partir da raiz do projeto');

      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          for (final secret in forbidden) {
            if (content.contains(secret)) offenders.add(entity.path);
          }
          // Heurística: token Z-API longo hardcoded em literal.
          final bearer = RegExp(r'''Bearer\s+[A-Za-z0-9_\-]{40,}''');
          if (bearer.hasMatch(content)) offenders.add('${entity.path} (bearer literal)');
        }
      }
      expect(offenders, isEmpty,
          reason: 'Segredos não devem ser embarcados no cliente: $offenders');
    });
  });
}
