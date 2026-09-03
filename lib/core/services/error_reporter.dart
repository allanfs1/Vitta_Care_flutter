import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Captura e registra erros não tratados em `tb_error_logs`.
///
/// **Por que não Crashlytics.** O `firebase_crashlytics` só suporta Android e
/// iOS. Este app roda em seis plataformas — web e desktop inclusos, e a web é
/// onde a maior parte do uso acontece hoje — então Crashlytics cobriria uma
/// fração do que quebra. Este reporter usa a infraestrutura que já existe
/// (Firestore) e funciona em todas. Crashlytics continua fazendo sentido
/// **em adição** a isto no mobile, pelo stack trace simbolizado.
///
/// Antes disto, um crash em produção só era descoberto se o usuário
/// reportasse — e a maioria não reporta, só para de usar a tela que quebrou.
class ErrorReporter {
  ErrorReporter._();

  static const String colecao = 'tb_error_logs';

  /// Teto de erros gravados por sessão. Um widget que quebra no `build` dispara
  /// o erro a cada frame: sem teto, um bug de layout viraria milhares de
  /// escritas em segundos — caro e inútil, já que são todas iguais.
  static const int _tetoSessao = 50;

  /// Janela de deduplicação. O mesmo erro dentro deste intervalo é contado,
  /// não regravado.
  static const Duration _janelaDedupe = Duration(minutes: 5);

  static bool _instalado = false;
  static int _gravados = 0;

  /// Assinatura do erro → quando foi gravado pela última vez.
  static final Map<String, DateTime> _vistos = HashMap();

  /// Resolve o id da clínica no momento do erro. Injetado pelo app para o
  /// reporter não depender de Riverpod (ele roda em contextos onde não há
  /// `ref`, como o handler de erro da própria zona).
  static String Function()? _clinicaAtual;

  /// `true` quando há Firestore para gravar. Sem Firebase o reporter continua
  /// logando no console, mas não tenta escrever.
  static bool _podeGravar = false;

  /// Instala os handlers globais. Chame uma vez, no `main`, **antes** de
  /// `runApp`.
  ///
  /// [podeGravar] deve refletir se o Firebase inicializou; [clinicaAtual]
  /// permite escopar o log por clínica quando ela já estiver resolvida.
  static void instalar({
    required bool podeGravar,
    String Function()? clinicaAtual,
  }) {
    _podeGravar = podeGravar;
    _clinicaAtual = clinicaAtual;
    if (_instalado) return;
    _instalado = true;

    // Erros do framework (build, layout, paint).
    final anterior = FlutterError.onError;
    FlutterError.onError = (details) {
      anterior?.call(details);
      registrar(
        details.exception,
        details.stack,
        contexto: details.context?.toDescription(),
        biblioteca: details.library,
      );
    };

    // Erros assíncronos que escapam da zona — futures sem catch, callbacks de
    // plugin. Sem este handler eles morriam silenciosamente.
    PlatformDispatcher.instance.onError = (erro, stack) {
      registrar(erro, stack, contexto: 'PlatformDispatcher');
      return true; // tratado: não derruba o isolate
    };
  }

  /// Registra um erro. Seguro de chamar de qualquer lugar — nunca lança.
  ///
  /// A gravação é *fire-and-forget* de propósito: o caminho de erro não pode
  /// esperar rede, e um reporter que trava o app é pior que erro nenhum.
  static void registrar(
    Object erro,
    StackTrace? stack, {
    String? contexto,
    String? biblioteca,
  }) {
    try {
      final assinatura = _assinatura(erro, stack);

      final agora = DateTime.now();
      final ultimoIgual = _vistos[assinatura];
      if (ultimoIgual != null && agora.difference(ultimoIgual) < _janelaDedupe) {
        return; // mesmo erro, janela ainda aberta
      }
      _vistos[assinatura] = agora;

      // Depois da dedupe, de propósito: um widget quebrado no `build` dispara
      // o erro a cada frame, e logar cada um afogaria o console justamente
      // quando alguém está tentando ler o stack trace.
      if (kDebugMode) {
        debugPrint('[ErrorReporter] $erro');
      }

      if (!_podeGravar || _gravados >= _tetoSessao) return;
      _gravados++;

      unawaited(_gravar(
        assinatura: assinatura,
        erro: erro,
        stack: stack,
        contexto: contexto,
        biblioteca: biblioteca,
        quando: agora,
      ));
    } catch (_) {
      // Um reporter que lança seria a pior falha possível: esconderia o erro
      // original e ainda criaria um segundo.
    }
  }

  static Future<void> _gravar({
    required String assinatura,
    required Object erro,
    required StackTrace? stack,
    required String? contexto,
    required String? biblioteca,
    required DateTime quando,
  }) async {
    try {
      await FirebaseFirestore.instance.collection(colecao).add({
        'assinatura': assinatura,
        'mensagem': _truncar(erro.toString(), 1000),
        'tipo': erro.runtimeType.toString(),
        'stack': _truncar(stack?.toString() ?? '', 4000),
        'contexto': contexto,
        'biblioteca': biblioteca,
        'plataforma': _plataforma(),
        'modo': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
        'clinicaId': _clinicaAtual?.call() ?? '',
        'em': Timestamp.fromDate(quando),
      });
    } catch (_) {
      // Sem rede ou sem permissão: perder o log é aceitável, travar não é.
    }
  }

  /// Assinatura estável do erro, para deduplicar.
  ///
  /// Usa tipo + primeira linha da mensagem + primeiro frame do stack. A
  /// mensagem inteira não serve: erros costumam trazer ids e valores que mudam
  /// a cada ocorrência ("nota nt_abc123 não encontrada"), e isso faria o mesmo
  /// bug parecer mil bugs diferentes.
  static String _assinatura(Object erro, StackTrace? stack) {
    final tipo = erro.runtimeType.toString();
    final primeiraLinha = erro.toString().split('\n').first;
    final mensagem = primeiraLinha.length > 120
        ? primeiraLinha.substring(0, 120)
        : primeiraLinha;

    var frame = '';
    final linhas = stack?.toString().split('\n') ?? const [];
    for (final l in linhas) {
      final t = l.trim();
      if (t.isEmpty) continue;
      frame = t.length > 120 ? t.substring(0, 120) : t;
      break;
    }
    return '$tipo|$mensagem|$frame';
  }

  static String _truncar(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  static String _plataforma() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  /// Zera o estado — usado nos testes para isolar cada caso.
  @visibleForTesting
  static void resetarParaTeste() {
    _gravados = 0;
    _vistos.clear();
    _podeGravar = false;
    _clinicaAtual = null;
  }

  /// Quantos erros esta sessão já gravou (ou tentou gravar).
  @visibleForTesting
  static int get gravadosNaSessao => _gravados;

  /// Expõe a assinatura para os testes verificarem a deduplicação.
  @visibleForTesting
  static String assinaturaDe(Object erro, StackTrace? stack) =>
      _assinatura(erro, stack);
}
