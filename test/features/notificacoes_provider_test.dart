import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/notificacoes_centro/notificacoes_provider.dart';
import 'package:vitta_app/features/notificacoes_centro/notificacoes_repository.dart';

void main() {
  group('NotificacoesNotifier', () {
    test('push insere no topo e incrementa não lidas', () async {
      final repo = MemoriaNotificacoesRepository(NotificacoesNotifier.demonstracao);
      final n = NotificacoesNotifier(repo, 'clinica-1');
      await n.carregar();
      final naoLidasAntes = n.state.where((x) => !x.read).length;
      n.push(
        type: NotificationType.overbooking,
        title: 'Realocação concluída',
        message: 'Maria → 10/07 14:30',
      );
      expect(n.state.first.title, 'Realocação concluída');
      expect(n.state.first.type, NotificationType.overbooking);
      expect(n.state.where((x) => !x.read).length, naoLidasAntes + 1);
    });

    test('add faz dedupe por id (atualiza em vez de duplicar)', () async {
      final repo = MemoriaNotificacoesRepository(NotificacoesNotifier.demonstracao);
      final n = NotificacoesNotifier(repo, 'clinica-1');
      await n.carregar();
      final total = n.state.length;
      final primeiro = n.state.first;
      n.add(primeiro.copyWith(read: true));
      expect(n.state.length, total); // não duplicou
      expect(n.state.where((x) => x.id == primeiro.id).length, 1);
      expect(n.state.firstWhere((x) => x.id == primeiro.id).read, isTrue);
    });

    test('markAllRead zera as não lidas', () async {
      final repo = MemoriaNotificacoesRepository(NotificacoesNotifier.demonstracao);
      final n = NotificacoesNotifier(repo, 'clinica-1');
      await n.carregar();
      n.markAllRead();
      expect(n.state.where((x) => !x.read), isEmpty);
    });
  });
}
