import 'package:speech_to_text/speech_to_text.dart';

/// Wrapper sobre [SpeechToText] para reconhecimento de voz em pt_BR.
///
/// Alvo principal: Flutter Web (Chrome). A inicialização solicita permissão
/// de microfone — em plataformas sem suporte [init] retorna `false` sem
/// lançar exceções.
class VoiceInputService {
  VoiceInputService() : _stt = SpeechToText();

  final SpeechToText _stt;

  bool _available = false;

  /// Inicializa o serviço e solicita permissão de microfone.
  ///
  /// Retorna `true` se a plataforma suporta STT e a permissão foi concedida.
  Future<bool> init() async {
    try {
      _available = await _stt.initialize(
        onError: (error) {
          // Erros são silenciados; o chamador usa [isListening] para reagir.
        },
        onStatus: (_) {},
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// `true` se a plataforma suporta STT e a permissão foi concedida.
  bool get isAvailable => _available;

  /// `true` enquanto o serviço estiver capturando áudio.
  bool get isListening => _stt.isListening;

  /// Inicia o reconhecimento de voz em pt_BR.
  ///
  /// [onResult] é chamado com o texto reconhecido e se o resultado é final.
  /// [onDone] é chamado quando o ouvinte para (timeout ou [stop]).
  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
    void Function()? onDone,
  }) async {
    if (!_available) return;
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'pt_BR',
          partialResults: true,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 5),
          onDevice: false,
          cancelOnError: false,
        ),
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
      );
      // Registra callback de término (status 'done' ou 'notListening').
      if (onDone != null) {
        _stt.statusListener = (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            onDone();
          }
        };
      }
    } catch (_) {
      // Silencia erros de plataforma; o chamador observa [isListening].
    }
  }

  /// Para o reconhecimento em curso.
  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  /// Libera os recursos do serviço.
  void dispose() {
    try {
      _stt.cancel();
    } catch (_) {}
  }
}
