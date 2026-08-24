import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import 'acessibilidade_screen.dart';
import 'aparencia_screen.dart';
import 'avancado_screen.dart';
import 'dados_privacidade_screen.dart';
import 'logo_editor_screen.dart';
import 'notificacoes_screen.dart';
import 'tema_screen.dart';
import 'tipografia_screen.dart';
import '../../totem/widgets/totem_config_panel.dart';
import '../../assistente/assistant_anchors.dart';
import '../../assistente/assistant_tours.dart';

/// Hub de Configurações do Sistema (Módulo 9). Lista as seções e abre cada uma.
class ConfiguracoesHubScreen extends ConsumerWidget {
  const ConfiguracoesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = <_Section>[
      _Section('Logotipo', 'Enviar e editar o logo da marca',
          Icons.image_outlined, AppColors.secondary, const LogoEditorScreen()),
      _Section('Aparência', 'Cores, paletas e fundo', Icons.palette_outlined,
          AppColors.primary, const AparenciaScreen()),
      _Section('Tipografia', 'Fonte, tamanho e espaçamento',
          Icons.text_fields, const Color(0xFF7C3AED), const TipografiaScreen()),
      _Section('Tema', 'Modo claro/escuro, contraste e cantos',
          Icons.contrast, const Color(0xFF0EA5E9), const TemaScreen()),
      _Section('Acessibilidade', 'Contraste, movimento e daltonismo',
          Icons.accessibility_new, AppColors.secondary, const AcessibilidadeScreen()),
      _Section('Notificações', 'Push, e-mail, sons e não perturbe',
          Icons.notifications_outlined, AppColors.warning, const NotificacoesScreen()),
      _Section('Totem', 'Autoatendimento: marca, fluxos, sugestões e horários',
          Icons.touch_app_outlined, const Color(0xFF14B8A6), const TotemConfigPanel()),
      _Section('Dados e Privacidade', 'Cache, exportar e excluir conta',
          Icons.privacy_tip_outlined, AppColors.danger, const DadosPrivacidadeScreen()),
      _Section('Avançado', 'Idioma, formatos, fuso e sobre',
          Icons.tune, const Color(0xFF374151), const AvancadoScreen()),
    ];

    final columns = Responsive.gridColumns(context, max: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ContentContainer(
        maxWidth: 820,
        child: GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: sections.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            mainAxisExtent: 96,
          ),
          itemBuilder: (context, i) {
            final card = _SectionCard(section: sections[i]);
            return sections[i].title == 'Totem'
                ? AssistantTarget(anchorId: HelpAnchors.totemCard, child: card)
                : card;
          },
        ),
      ),
    );
  }
}

class _Section {
  _Section(this.title, this.subtitle, this.icon, this.color, this.screen);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});
  final _Section section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => section.screen)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: section.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(section.icon, color: section.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(section.title, style: theme.textTheme.titleMedium),
                Text(section.subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
