/// Síntese de voz (TTS) do Monitor da Recepção (§4.1).
///
/// Usa a Web Speech API do navegador na web; nas demais plataformas vira no-op
/// (o monitor é, na prática, um display web). A seleção é feita por import
/// condicional para não quebrar a compilação fora da web.
library;

export 'recepcao_tts_stub.dart'
    if (dart.library.html) 'recepcao_tts_web.dart';
