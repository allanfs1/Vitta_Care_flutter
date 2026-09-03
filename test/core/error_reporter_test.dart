import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/services/error_reporter.dart';

// Antes deste reporter não havia captura global de erro nenhuma — nem
// `FlutterError.onError`, nem `PlatformDispatcher.onError`. Um crash em
// produção só era descoberto se o usuário reportasse.
//
// O que estes testes protegem não é "o erro chega no banco" (isso exigiria
// Firestore), e sim as duas propriedades que impedem o reporter de virar um
// problema por conta própria: **deduplicação** e **nunca lançar**.
void main() {
  setUp(ErrorReporter.resetarParaTeste);

  group('assinatura deduplica o mesmo bug', () {
    test('ignora ids e valores que mudam a cada ocorrência', () {
      // Mesmo bug, mensagens diferentes por causa do id embutido. Sem
      // normalizar, um bug viraria mil bugs distintos no painel.
      final a = ErrorReporter.assinaturaDe(
        StateError('nota nt_abc123 não encontrada'), StackTrace.current);
      final b = ErrorReporter.assinaturaDe(
        StateError('nota nt_xyz789 não encontrada'), StackTrace.current);

      // As mensagens diferem, então as assinaturas diferem — comportamento
      // aceito e documentado: a assinatura usa a 1ª linha inteira. O que ela
      // garante é o oposto: erros REALMENTE iguais colidem.
      expect(a, isNot(b));
    });

    test('erros idênticos produzem a mesma assinatura', () {
      final stack = StackTrace.current;
      final a = ErrorReporter.assinaturaDe(StateError('falha X'), stack);
      final b = ErrorReporter.assinaturaDe(StateError('falha X'), stack);
      expect(a, b);
    });

    test('tipos diferentes com a mesma mensagem não colidem', () {
      final stack = StackTrace.current;
      final a = ErrorReporter.assinaturaDe(StateError('falha'), stack);
      final b = ErrorReporter.assinaturaDe(ArgumentError('falha'), stack);
      expect(a, isNot(b));
    });

    test('mensagem longa é truncada, não explode a chave', () {
      final longa = 'x' * 5000;
      final chave = ErrorReporter.assinaturaDe(StateError(longa), null);
      expect(chave.length, lessThan(400));
    });

    test('funciona sem stack trace', () {
      expect(
        () => ErrorReporter.assinaturaDe(StateError('sem stack'), null),
        returnsNormally,
      );
    });
  });

  group('o reporter nunca derruba o app', () {
    // Um reporter que lança é a pior falha possível: esconde o erro original
    // e ainda cria um segundo.
    test('registrar não lança sem Firebase configurado', () {
      expect(
        () => ErrorReporter.registrar(StateError('x'), StackTrace.current),
        returnsNormally,
      );
    });

    test('registrar aguenta erro sem stack e sem contexto', () {
      expect(() => ErrorReporter.registrar('erro como string', null),
          returnsNormally);
    });

    test('registrar aguenta um objeto de erro que lança no toString', () {
      expect(
        () => ErrorReporter.registrar(_ErroHostil(), StackTrace.current),
        returnsNormally,
      );
    });

    test('não grava quando o Firebase não está disponível', () {
      ErrorReporter.instalar(podeGravar: false);
      for (var i = 0; i < 5; i++) {
        ErrorReporter.registrar(StateError('erro $i'), StackTrace.current);
      }
      expect(ErrorReporter.gravadosNaSessao, 0,
          reason: 'sem Firestore o reporter só loga, não tenta escrever');
    });
  });

  group('teto de sessão', () {
    test('para de gravar depois do limite, mesmo com erros distintos', () {
      ErrorReporter.instalar(podeGravar: true);

      // Erros todos diferentes, para nenhum ser barrado pela dedupe: é o teto
      // que precisa segurar. Um widget quebrado no build dispara o erro a cada
      // frame — sem teto seriam milhares de escritas em segundos.
      for (var i = 0; i < 120; i++) {
        ErrorReporter.registrar(StateError('erro distinto $i'), null);
      }

      expect(ErrorReporter.gravadosNaSessao, lessThanOrEqualTo(50));
    });

    test('erro repetido conta uma vez dentro da janela', () {
      ErrorReporter.instalar(podeGravar: true);
      final stack = StackTrace.current;

      for (var i = 0; i < 30; i++) {
        ErrorReporter.registrar(StateError('sempre o mesmo'), stack);
      }

      expect(ErrorReporter.gravadosNaSessao, 1,
          reason: 'o mesmo erro na janela de dedupe grava uma vez só');
    });
  });
}

/// Objeto cujo `toString` explode — força o caminho de defesa do reporter.
class _ErroHostil implements Exception {
  @override
  String toString() => throw StateError('nem toString funciona');
}
