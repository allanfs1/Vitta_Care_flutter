/// Validadores de formulário (PU-02..PU-05).
class Validators {
  Validators._();

  static String? required(String? value, [String field = 'Campo']) {
    if (value == null || value.trim().isEmpty) return '$field é obrigatório';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'E-mail é obrigatório';
    final regex = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!regex.hasMatch(value.trim())) return 'E-mail inválido';
    return null;
  }

  /// Valida CPF com dígitos verificadores.
  static String? cpf(String? value) {
    if (value == null || value.isEmpty) return 'CPF é obrigatório';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return 'CPF deve ter 11 dígitos';
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return 'CPF inválido';

    int calcCheck(int len) {
      var sum = 0;
      for (var i = 0; i < len; i++) {
        sum += int.parse(digits[i]) * (len + 1 - i);
      }
      final rest = (sum * 10) % 11;
      return rest == 10 ? 0 : rest;
    }

    if (calcCheck(9) != int.parse(digits[9]) ||
        calcCheck(10) != int.parse(digits[10])) {
      return 'CPF inválido';
    }
    return null;
  }

  static String? cep(String? value) {
    if (value == null || value.isEmpty) return 'CEP é obrigatório';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return 'CEP deve ter 8 dígitos';
    return null;
  }

  static String? cnpj(String? value) {
    if (value == null || value.isEmpty) return 'CNPJ é obrigatório';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 14) return 'CNPJ deve ter 14 dígitos';
    return null;
  }

  /// Senha forte: mín. 8 caracteres com maiúscula, minúscula, número e especial.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Senha é obrigatória';
    if (value.length < 8) return 'Mínimo de 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Inclua uma letra maiúscula';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Inclua uma letra minúscula';
    if (!RegExp(r'\d').hasMatch(value)) return 'Inclua um número';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]').hasMatch(value)) {
      return 'Inclua um caractere especial';
    }
    return null;
  }
}
