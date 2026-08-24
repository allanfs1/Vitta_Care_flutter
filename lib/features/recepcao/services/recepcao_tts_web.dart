// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';

/// Locuta [text] em pt-BR usando a Web Speech API do navegador.
void speakPtBr(String text,
    {double rate = 0.95, double pitch = 1.0, int times = 1}) {
  final synth = html.window.speechSynthesis;
  if (synth == null) return;
  synth.cancel(); // evita sobreposição de falas
  for (var i = 0; i < times; i++) {
    final utterance = html.SpeechSynthesisUtterance(text)
      ..lang = 'pt-BR'
      ..rate = rate
      ..pitch = pitch
      ..volume = 1.0;
    synth.speak(utterance);
  }
}

void cancelSpeech() {
  html.window.speechSynthesis?.cancel();
}

/// Aviso sonoro curto (bipe) — toca um WAV gerado em memória via `AudioElement`.
void beep() {
  try {
    final uri = 'data:audio/wav;base64,${base64Encode(_beepWav())}';
    html.AudioElement(uri)
      ..volume = 0.35
      ..play();
  } catch (_) {
    // Áudio indisponível (ex.: sem interação do usuário) — ignora.
  }
}

/// WAV PCM 8-bit mono (~160ms, 880 Hz) com fade-in/out para evitar clique.
Uint8List _beepWav() {
  const sampleRate = 8000;
  const durationMs = 160;
  const freq = 880.0;
  final samples = (sampleRate * durationMs / 1000).round();
  final data = Uint8List(44 + samples);

  void w32(int off, int v) {
    data[off] = v & 0xff;
    data[off + 1] = (v >> 8) & 0xff;
    data[off + 2] = (v >> 16) & 0xff;
    data[off + 3] = (v >> 24) & 0xff;
  }

  void w16(int off, int v) {
    data[off] = v & 0xff;
    data[off + 1] = (v >> 8) & 0xff;
  }

  data.setRange(0, 4, 'RIFF'.codeUnits);
  w32(4, 36 + samples);
  data.setRange(8, 12, 'WAVE'.codeUnits);
  data.setRange(12, 16, 'fmt '.codeUnits);
  w32(16, 16);
  w16(20, 1); // PCM
  w16(22, 1); // mono
  w32(24, sampleRate);
  w32(28, sampleRate); // byte rate (8-bit mono)
  w16(32, 1); // block align
  w16(34, 8); // bits/sample
  data.setRange(36, 40, 'data'.codeUnits);
  w32(40, samples);

  for (var i = 0; i < samples; i++) {
    final t = i / sampleRate;
    final fadeIn = i < samples * 0.1 ? i / (samples * 0.1) : 1.0;
    final fadeOut =
        i > samples * 0.8 ? (samples - i) / (samples * 0.2) : 1.0;
    final env = fadeIn * fadeOut;
    final value = (sin(2 * pi * freq * t) * env * 100 + 128).round();
    data[44 + i] = value.clamp(0, 255);
  }
  return data;
}

bool get isSpeechAvailable => html.window.speechSynthesis != null;
