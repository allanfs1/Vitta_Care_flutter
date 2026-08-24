/// Implementação no-op para plataformas sem Web Speech API.
void speakPtBr(String text,
    {double rate = 0.95, double pitch = 1.0, int times = 1}) {}

void cancelSpeech() {}

/// Aviso sonoro curto (no-op fora da web).
void beep() {}

/// `true` quando há síntese de voz disponível (sempre `false` fora da web).
bool get isSpeechAvailable => false;
