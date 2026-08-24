import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/utils/validators.dart';

/// Testes unitários dos validadores de formulário (PU-02..PU-05, PC-01).
void main() {
  group('Validators.required', () {
    test('rejeita vazio e aceita preenchido', () {
      expect(Validators.required('', 'Nome'), isNotNull);
      expect(Validators.required('   '), isNotNull);
      expect(Validators.required('Maria'), isNull);
    });
  });

  group('Validators.email', () {
    test('aceita e-mails válidos', () {
      expect(Validators.email('user@vitta.app'), isNull);
      expect(Validators.email('a.b-c+x@sub.dominio.com'), isNull);
    });
    test('rejeita e-mails inválidos', () {
      expect(Validators.email('sem-arroba'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });
  });

  group('Validators.cpf (dígitos verificadores)', () {
    test('aceita CPFs válidos (com e sem máscara)', () {
      expect(Validators.cpf('529.982.247-25'), isNull);
      expect(Validators.cpf('52998224725'), isNull);
      expect(Validators.cpf('111.444.777-35'), isNull);
    });
    test('rejeita dígitos verificadores incorretos', () {
      expect(Validators.cpf('529.982.247-24'), isNotNull);
      expect(Validators.cpf('12345678900'), isNotNull);
    });
    test('rejeita sequências repetidas e tamanho errado', () {
      expect(Validators.cpf('111.111.111-11'), isNotNull);
      expect(Validators.cpf('123'), isNotNull);
    });
  });

  group('Validators.cep / cnpj', () {
    test('cep exige 8 dígitos', () {
      expect(Validators.cep('01001-000'), isNull);
      expect(Validators.cep('123'), isNotNull);
    });
    test('cnpj exige 14 dígitos', () {
      expect(Validators.cnpj('12.345.678/0001-90'), isNull);
      expect(Validators.cnpj('123'), isNotNull);
    });
  });

  group('Validators.password (política forte)', () {
    test('aceita senha forte completa', () {
      expect(Validators.password('Senha@123'), isNull);
    });
    test('rejeita por critério faltante', () {
      expect(Validators.password('curto1!'), isNotNull); // < 8
      expect(Validators.password('senha@123'), isNotNull); // sem maiúscula
      expect(Validators.password('SENHA@123'), isNotNull); // sem minúscula
      expect(Validators.password('Senha@abc'), isNotNull); // sem número
      expect(Validators.password('Senha1234'), isNotNull); // sem especial
    });
  });
}
