import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../agent/voice_input_service.dart';

/// Botão de microfone autossuficiente que integra [VoiceInputService].
///
/// - Ao tocar, inicializa o serviço (lazy) e alterna ouvir/parar.
/// - Enquanto ouvindo, exibe animação de opacidade pulsante e cor rosa.
/// - Se STT indisponível, o ícone é esmaecido e um [Tooltip] é exibido.
/// - Repassa o texto reconhecido (parcial e final) via [onText].
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({
    super.key,
    required this.onText,
    this.enabled = true,
  });

  /// Chamado com o texto reconhecido (pode ser chamado múltiplas vezes com
  /// texto parcial; o último valor é o texto acumulado atual).
  final void Function(String text) onText;

  /// Quando `false`, o botão fica desabilitado visualmente.
  final bool enabled;

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton>
    with SingleTickerProviderStateMixin {
  late final VoiceInputService _service;
  late final AnimationController _pulse;
  late final Animation<double> _opacity;

  bool _initialized = false;
  bool _sttAvailable = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _service = VoiceInputService();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pulse.reverse();
        } else if (status == AnimationStatus.dismissed) {
          if (_listening) _pulse.forward();
        }
      });

    _opacity = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    final available = await _service.init();
    if (mounted) {
      setState(() {
        _initialized = true;
        _sttAvailable = available;
      });
    }
  }

  Future<void> _toggle() async {
    if (!widget.enabled) return;

    await _ensureInit();

    if (!_sttAvailable) return;

    if (_listening) {
      await _service.stop();
      if (mounted) {
        setState(() => _listening = false);
        _pulse.stop();
        _pulse.reset();
      }
    } else {
      await _service.start(
        onResult: (text, isFinal) {
          if (text.isNotEmpty) {
            widget.onText(text);
          }
        },
        onDone: () {
          if (mounted) {
            setState(() => _listening = false);
            _pulse.stop();
            _pulse.reset();
          }
        },
      );
      if (mounted) {
        setState(() => _listening = _service.isListening);
        if (_listening) _pulse.forward();
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Antes de inicializar, assume disponível para exibir ícone ativo.
    final sttUnavailable = _initialized && !_sttAvailable;
    final effectiveEnabled = widget.enabled && !sttUnavailable;

    final icon = _listening ? Icons.mic : Icons.mic_off;
    final color = _listening
        ? AppColors.pinkAccent
        : sttUnavailable
            ? AppColors.textSecondaryOf(context)
            : AppColors.textSecondaryOf(context);

    Widget button = AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _listening ? _opacity.value : 1.0,
          child: child,
        );
      },
      child: IconButton(
        onPressed: effectiveEnabled ? _toggle : null,
        icon: Icon(icon, color: color),
        tooltip: sttUnavailable
            ? 'Reconhecimento de voz indisponível neste dispositivo/navegador'
            : _listening
                ? 'Parar gravação'
                : 'Ativar entrada por voz',
        splashRadius: 20,
      ),
    );

    if (sttUnavailable) {
      button = Tooltip(
        message:
            'Reconhecimento de voz indisponível neste dispositivo/navegador',
        child: button,
      );
    }

    return button;
  }
}
