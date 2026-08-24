import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/configuracoes_provider.dart';
import '../widgets/config_widgets.dart';
import '../widgets/logo_processor.dart';

/// Editor de logotipo: enviar, escalar, cortar, limpar fundo, filtros e
/// corte inteligente. Salva o resultado (PNG base64) nas configurações.
class LogoEditorScreen extends ConsumerStatefulWidget {
  const LogoEditorScreen({super.key});

  @override
  ConsumerState<LogoEditorScreen> createState() => _LogoEditorScreenState();
}

class _LogoEditorScreenState extends ConsumerState<LogoEditorScreen> {
  Uint8List? _original;
  Uint8List? _preview;
  LogoEditOptions _opt = const LogoEditOptions();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Pré-carrega o logo atual (se houver) para edição.
    final current = ref.read(settingsProvider).logoBytes;
    if (current != null) {
      _original = current;
      WidgetsBinding.instance.addPostFrameCallback((_) => _updatePreview());
    }
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _original = bytes;
      _opt = const LogoEditOptions();
    });
    _updatePreview();
  }

  Future<void> _updatePreview() async {
    final src = _original;
    if (src == null) return;
    setState(() => _busy = true);
    final brand = ref.read(settingsProvider).primary.toARGB32();
    final result = await Future(() =>
        LogoProcessor.process(src, _opt.copyWith(size: 256, brandColor: brand)));
    if (!mounted) return;
    setState(() {
      _preview = result;
      _busy = false;
    });
  }

  void _set(LogoEditOptions opt) {
    setState(() => _opt = opt);
    _updatePreview();
  }

  Future<void> _apply() async {
    final src = _original;
    if (src == null) return;
    setState(() => _busy = true);
    final brand = ref.read(settingsProvider).primary.toARGB32();
    final out = await Future(() =>
        LogoProcessor.process(src, _opt.copyWith(brandColor: brand)));
    ref.read(settingsProvider.notifier).setLogo(base64Encode(out));
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logotipo atualizado.')),
    );
    Navigator.of(context).pop();
  }

  void _removeLogo() {
    ref.read(settingsProvider.notifier).setLogo(null);
    setState(() {
      _original = null;
      _preview = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = _original != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logotipo'),
        actions: [
          if (ref.watch(settingsProvider).logoBytes != null)
            IconButton(
              tooltip: 'Remover logo',
              onPressed: _removeLogo,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      bottomNavigationBar: hasImage
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _apply,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: const Text('Aplicar logotipo'),
                  ),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Preview (xadrez para mostrar transparência)
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: theme.dividerColor),
                image: const DecorationImage(
                  image: AssetImage('assets/images/logo.png'),
                  opacity: 0,
                ),
              ),
              child: _CheckerBoard(
                child: _preview != null
                    ? Image.memory(_preview!, fit: BoxFit.contain, gaplessPlayback: true)
                    : hasImage
                        ? Image.memory(_original!, fit: BoxFit.contain)
                        : const Center(
                            child: Icon(Icons.image_outlined,
                                size: 48, color: AppColors.textTertiary),
                          ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.upload_outlined),
              label: Text(hasImage ? 'Trocar imagem' : 'Enviar imagem'),
            ),
          ),
          if (hasImage) ...[
            ConfigSection(
              title: 'Ajustes inteligentes',
              children: [
                ToggleSettingTile(
                  title: 'Limpar fundo automaticamente',
                  subtitle: 'Remove o fundo uniforme deixando transparente',
                  icon: Icons.auto_fix_high,
                  value: _opt.removeBackground,
                  onChanged: (v) => _set(_opt.copyWith(removeBackground: v)),
                ),
                ToggleSettingTile(
                  title: 'Corte inteligente',
                  subtitle: 'Recorta automaticamente nas bordas do conteúdo',
                  icon: Icons.crop_free,
                  value: _opt.smartCrop,
                  onChanged: (v) => _set(_opt.copyWith(smartCrop: v)),
                ),
                ToggleSettingTile(
                  title: 'Formato circular',
                  subtitle: 'Aplica máscara redonda ao logo',
                  icon: Icons.circle_outlined,
                  value: _opt.circle,
                  onChanged: (v) => _set(_opt.copyWith(circle: v)),
                ),
              ],
            ),
            ConfigSection(
              title: 'Escala / zoom',
              subtitle: '${(_opt.zoom * 100).round()}%',
              children: [
                Slider(
                  value: _opt.zoom,
                  min: 1.0,
                  max: 3.0,
                  divisions: 20,
                  label: '${(_opt.zoom * 100).round()}%',
                  onChanged: (v) => setState(() => _opt = _opt.copyWith(zoom: v)),
                  onChangeEnd: (_) => _updatePreview(),
                ),
              ],
            ),
            ConfigSection(
              title: 'Filtros inteligentes',
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SegmentedChoice<LogoFilter>(
                    options: LogoFilter.values,
                    selected: _opt.filter,
                    labelOf: (f) => f.label,
                    onSelected: (f) => _set(_opt.copyWith(filter: f)),
                  ),
                ),
              ],
            ),
            ConfigSection(
              title: 'Tamanho de saída',
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SegmentedChoice<int>(
                    options: const [128, 256, 512],
                    selected: _opt.size,
                    labelOf: (s) => '${s}px',
                    onSelected: (s) => setState(() => _opt = _opt.copyWith(size: s)),
                  ),
                ),
              ],
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Envie uma imagem (PNG ou JPG) para personalizar o logotipo da '
                'marca exibido no login, no menu e nos cabeçalhos.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

/// Fundo xadrez para evidenciar a transparência do logo.
class _CheckerBoard extends StatelessWidget {
  const _CheckerBoard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _CheckerPainter()),
          Padding(padding: const EdgeInsets.all(AppSpacing.md), child: child),
        ],
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    final light = Paint()..color = const Color(0xFFF0F0F3);
    final dark = Paint()..color = const Color(0xFFDDDDE3);
    canvas.drawRect(Offset.zero & size, light);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        if (((x / cell).floor() + (y / cell).floor()) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
