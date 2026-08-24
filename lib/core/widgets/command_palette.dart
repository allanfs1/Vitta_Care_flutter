import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../modules/module.dart';
import '../modules/module_registry.dart';
import '../services/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// ─────────────────────────── Data model ───────────────────────────

enum CommandCategory { action, navigation, clinica, paciente, agendamento, recent }

class CommandItem {
  const CommandItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.category,
    this.subtitle,
    this.route,
    this.onExecute,
    this.keywords = const [],
    this.badge,
  });

  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final CommandCategory category;
  final String? route;
  final VoidCallback? onExecute;
  final List<String> keywords;
  final String? badge;
}

// ───────────────────── Fuzzy search helper ─────────────────────────

String _normalize(String s) =>
    s.toLowerCase()
        .replaceAll(RegExp('[áàãâä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòõôö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ç', 'c');

/// Pontua a relevância de [item] para [query]. 0 = não casa.
/// Prioriza: título exato > prefixo > início de palavra > substring;
/// depois subtítulo e palavras-chave. Permite ordenar por relevância.
int _scoreItem(String query, CommandItem item) {
  final q = _normalize(query.trim());
  if (q.isEmpty) return 1; // sem busca: todos passam (ordem original)
  final title = _normalize(item.title);
  if (title == q) return 1000;
  if (title.startsWith(q)) return 850;
  if (title.contains(' $q')) return 700; // início de palavra
  if (title.contains(q)) return 500;

  final sub = _normalize(item.subtitle ?? '');
  if (sub.startsWith(q)) return 350;
  if (sub.contains(q)) return 250;

  var best = 0;
  for (final kw in item.keywords) {
    final k = _normalize(kw);
    if (k == q) {
      best = best < 320 ? 320 : best;
    } else if (k.startsWith(q)) {
      best = best < 220 ? 220 : best;
    } else if (k.contains(q)) {
      best = best < 120 ? 120 : best;
    }
  }
  return best;
}

// ──────────────── Default items from modules ──────────────────────

List<CommandItem> _buildNavigationItems() {
  final items = <CommandItem>[];
  for (final m in ModuleRegistry.modules) {
    if (m.route == null) continue;
    if (m.status == ModuleStatus.planned) continue;
    items.add(CommandItem(
      id: 'nav_${m.id}',
      title: m.title,
      subtitle: m.description,
      icon: m.icon,
      category: CommandCategory.navigation,
      route: m.route,
      keywords: [m.code, m.id],
      badge: m.priority == ModulePriority.p0 ? 'Core' : null,
    ));
  }
  return items;
}

List<CommandItem> _buildActionItems() {
  return const [
    CommandItem(
      id: 'act_new_appointment',
      title: 'Novo agendamento',
      subtitle: 'Criar um novo agendamento de consulta',
      icon: Icons.add_circle_outline,
      category: CommandCategory.action,
      route: '/agendamentos',
      keywords: ['criar', 'agendar', 'consulta', 'marcar'],
    ),
    CommandItem(
      id: 'act_view_patients',
      title: 'Ver pacientes do dia',
      subtitle: 'Lista de pacientes com consulta hoje',
      icon: Icons.people_outline,
      category: CommandCategory.action,
      route: '/agendamentos',
      keywords: ['paciente', 'lista', 'hoje'],
    ),
    CommandItem(
      id: 'act_reports',
      title: 'Relatórios de absenteísmo',
      subtitle: 'Análise de faltas e indicadores',
      icon: Icons.bar_chart_outlined,
      category: CommandCategory.action,
      route: '/absenteismo',
      keywords: ['relatorio', 'faltas', 'grafico', 'indicadores'],
    ),
    CommandItem(
      id: 'act_whatsapp',
      title: 'Enviar mensagem WhatsApp',
      subtitle: 'Acesse o painel de mensagens automáticas',
      icon: Icons.chat_outlined,
      category: CommandCategory.action,
      route: '/whatsapp',
      keywords: ['mensagem', 'sms', 'zapi', 'notificacao'],
    ),
    CommandItem(
      id: 'act_ai',
      title: 'Perguntar à IA',
      subtitle: 'Consulte a inteligência artificial sobre dados clínicos',
      icon: Icons.auto_awesome_outlined,
      category: CommandCategory.action,
      route: '/ia',
      keywords: ['inteligencia', 'artificial', 'chat', 'analise'],
    ),
    CommandItem(
      id: 'act_change_plan',
      title: 'Alterar plano',
      subtitle: 'Trocar ou comparar planos de assinatura',
      icon: Icons.swap_horiz,
      category: CommandCategory.action,
      route: '/choose-plan?change=true',
      keywords: ['plano', 'assinatura', 'upgrade', 'trocar'],
    ),
    CommandItem(
      id: 'act_settings',
      title: 'Configurações do sistema',
      subtitle: 'Tema, acessibilidade e preferências',
      icon: Icons.settings_outlined,
      category: CommandCategory.action,
      route: '/configuracoes',
      keywords: ['config', 'tema', 'dark', 'claro', 'acessibilidade'],
    ),
    CommandItem(
      id: 'act_profile',
      title: 'Meu perfil',
      subtitle: 'Editar dados pessoais e segurança',
      icon: Icons.person_outline,
      category: CommandCategory.action,
      route: '/perfil-usuario',
      keywords: ['perfil', 'usuario', 'conta', 'dados'],
    ),
  ];
}

// ────────────────────── Category labels ────────────────────────────

String _categoryLabel(CommandCategory c) {
  switch (c) {
    case CommandCategory.navigation:
      return 'Navegação';
    case CommandCategory.action:
      return 'Ações rápidas';
    case CommandCategory.recent:
      return 'Recentes';
    case CommandCategory.clinica:
      return 'Clínicas';
    case CommandCategory.paciente:
      return 'Pacientes';
    case CommandCategory.agendamento:
      return 'Agendamentos';
  }
}

IconData _categoryIcon(CommandCategory c) {
  switch (c) {
    case CommandCategory.navigation:
      return Icons.near_me_outlined;
    case CommandCategory.action:
      return Icons.flash_on_outlined;
    case CommandCategory.recent:
      return Icons.history;
    case CommandCategory.clinica:
      return Icons.local_hospital_outlined;
    case CommandCategory.paciente:
      return Icons.person_outline;
    case CommandCategory.agendamento:
      return Icons.calendar_today_outlined;
  }
}

// ─────────────────────── The Command Palette ──────────────────────

/// Shows the global command palette overlay. Call from anywhere.
Future<void> showCommandPalette(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar busca',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, anim, anim2, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.03),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
    pageBuilder: (context, anim1, anim2) {
      return const _CommandPaletteOverlay();
    },
  );
}

class _CommandPaletteOverlay extends ConsumerStatefulWidget {
  const _CommandPaletteOverlay();

  @override
  ConsumerState<_CommandPaletteOverlay> createState() =>
      _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState
    extends ConsumerState<_CommandPaletteOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scroll = ScrollController();
  int _highlightedIndex = 0;

  late final List<CommandItem> _staticItems;

  @override
  void initState() {
    super.initState();
    _staticItems = [
      ..._buildNavigationItems(),
      ..._buildActionItems(),
    ];
    // Intercepta as teclas de navegação ANTES da edição de texto (corrige a
    // navegação por teclado que não funcionava com o KeyboardListener).
    _focusNode.onKeyEvent = _handleKeyEvent;
    _controller.addListener(() {
      setState(() => _highlightedIndex = 0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Itens estáticos + entidades reais (clínicas do usuário).
  List<CommandItem> _items() {
    final clinics = ref.read(userClinicsProvider);
    final selectedId = ref.read(selectedClinicIdProvider);
    final clinicItems = [
      for (final c in clinics)
        CommandItem(
          id: 'clinic_${c.id}',
          title: c.name,
          subtitle: c.id == selectedId
              ? 'Unidade atual'
              : 'Trocar para esta unidade',
          icon: Icons.local_hospital_outlined,
          category: CommandCategory.clinica,
          keywords: [
            c.razaoSocial ?? '',
            c.email ?? '',
            c.address.city,
            'clinica',
            'unidade',
          ],
          badge: c.id == selectedId ? 'Atual' : null,
          onExecute: () =>
              ref.read(selectedClinicIdProvider.notifier).select(c.id),
        ),
    ];
    return [..._staticItems, ...clinicItems];
  }

  List<CommandItem> get _filtered {
    final q = _controller.text.trim();
    final items = _items();
    if (q.isEmpty) return items;
    final scored = <MapEntry<CommandItem, int>>[];
    for (final it in items) {
      final s = _scoreItem(q, it);
      if (s > 0) scored.add(MapEntry(it, s));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in scored) e.key];
  }

  Map<CommandCategory, List<CommandItem>> get _grouped {
    final filtered = _filtered;
    final map = <CommandCategory, List<CommandItem>>{};
    for (final c in CommandCategory.values) {
      final items = filtered.where((i) => i.category == c).toList();
      if (items.isNotEmpty) map[c] = items;
    }
    return map;
  }

  List<CommandItem> get _flatFiltered {
    final grouped = _grouped;
    final flat = <CommandItem>[];
    for (final c in CommandCategory.values) {
      if (grouped.containsKey(c)) flat.addAll(grouped[c]!);
    }
    return flat;
  }

  void _executeItem(CommandItem item) {
    Navigator.of(context).pop();
    if (item.route != null) {
      context.go(item.route!);
    }
    item.onExecute?.call();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final flat = _flatFiltered;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (flat.isNotEmpty) {
        setState(() => _highlightedIndex = (_highlightedIndex + 1) % flat.length);
        _scrollToHighlighted();
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (flat.isNotEmpty) {
        setState(() => _highlightedIndex =
            (_highlightedIndex - 1 + flat.length) % flat.length);
        _scrollToHighlighted();
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (flat.isNotEmpty && _highlightedIndex < flat.length) {
        _executeItem(flat[_highlightedIndex]);
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Mantém o item destacado visível ao navegar pelo teclado (estimativa de
  /// alturas: cabeçalhos vs. tiles).
  void _scrollToHighlighted() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      const tileH = 58.0;
      const headerH = 34.0;
      final grouped = _grouped;
      var offset = 0.0;
      var flatIdx = 0;
      var found = false;
      for (final category in CommandCategory.values) {
        final items = grouped[category];
        if (items == null) continue;
        offset += headerH;
        for (var i = 0; i < items.length; i++) {
          if (flatIdx == _highlightedIndex) {
            found = true;
            break;
          }
          offset += tileH;
          flatIdx++;
        }
        if (found) break;
      }
      final target =
          (offset - 90).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final flat = _flatFiltered;
    final listItems = _buildListItems(grouped);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final hintColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Align(
      alignment: const Alignment(0, -0.3),
      child: Material(
        color: Colors.transparent,
        child: Container(
            width: 580,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 48,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ───── Search field ─────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: hintColor, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Buscar módulos, ações, atalhos…',
                            hintStyle: TextStyle(color: hintColor),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceAltDark
                              : AppColors.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          'Esc',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: hintColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: borderColor, height: 16),

                // ───── Results ─────
                if (flat.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.search_off,
                            size: 40, color: hintColor),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhum resultado encontrado',
                          style: TextStyle(
                            color: hintColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tente buscar por outro termo',
                          style: TextStyle(
                            color: hintColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.only(bottom: 8),
                      shrinkWrap: true,
                      itemCount: listItems.length,
                      itemBuilder: (context, index) => listItems[index],
                    ),
                  ),

                // ───── Footer / hints ─────
                Divider(color: borderColor, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      _FooterHint(
                        icon: Icons.keyboard_arrow_up,
                        icon2: Icons.keyboard_arrow_down,
                        label: 'Navegar',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 16),
                      _FooterHint(
                        icon: Icons.keyboard_return,
                        label: 'Abrir',
                        isDark: isDark,
                      ),
                      const Spacer(),
                      Text(
                        '${flat.length} resultado${flat.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  List<Widget> _buildListItems(
      Map<CommandCategory, List<CommandItem>> grouped) {
    final widgets = <Widget>[];
    int flatIndex = 0;
    for (final category in CommandCategory.values) {
      final items = grouped[category];
      if (items == null) continue;
      widgets.add(_SectionHeader(
        label: _categoryLabel(category),
        icon: _categoryIcon(category),
        isDark: Theme.of(context).brightness == Brightness.dark,
      ));
      for (final item in items) {
        final isHighlighted = flatIndex == _highlightedIndex;
        final currentFlatIndex = flatIndex;
        widgets.add(_ResultTile(
          item: item,
          highlighted: isHighlighted,
          isDark: Theme.of(context).brightness == Brightness.dark,
          onTap: () => _executeItem(item),
          onHover: () => setState(() => _highlightedIndex = currentFlatIndex),
        ));
        flatIndex++;
      }
    }
    return widgets;
  }
}

// ─────────────────── Section header ───────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.isDark,
  });
  final String label;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────── Result tile ─────────────────────────────────

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.item,
    required this.highlighted,
    required this.isDark,
    required this.onTap,
    required this.onHover,
  });

  final CommandItem item;
  final bool highlighted;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final highlightBg = isDark
        ? AppColors.surfaceAltDark
        : AppColors.primaryLight.withValues(alpha: 0.5);
    final iconColor = highlighted
        ? AppColors.primary
        : isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondary;

    return MouseRegion(
      onEnter: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: highlighted ? highlightBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: highlighted
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(item.icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            highlighted ? FontWeight.w600 : FontWeight.w500,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null)
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (item.badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Text(
                    item.badge!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              if (highlighted) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_return,
                  size: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Footer hint ──────────────────────────────

class _FooterHint extends StatelessWidget {
  const _FooterHint({
    required this.icon,
    required this.label,
    required this.isDark,
    this.icon2,
  });

  final IconData icon;
  final IconData? icon2;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final textColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    Widget kbd(IconData ic) => Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor),
          ),
          child: Icon(ic, size: 14, color: textColor),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        kbd(icon),
        if (icon2 != null) ...[const SizedBox(width: 2), kbd(icon2!)],
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }
}

// ─────────────────── Global keyboard shortcut ─────────────────────

/// Wrap the app (or AppShell) with this widget to enable Ctrl+K / Cmd+K
/// anywhere in the app.
class CommandPaletteShortcut extends StatelessWidget {
  const CommandPaletteShortcut({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyK,
        ): const _ShowCommandPaletteIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.keyK,
        ): const _ShowCommandPaletteIntent(),
      },
      child: Actions(
        actions: {
          _ShowCommandPaletteIntent: CallbackAction<_ShowCommandPaletteIntent>(
            onInvoke: (_) {
              showCommandPalette(context);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class _ShowCommandPaletteIntent extends Intent {
  const _ShowCommandPaletteIntent();
}
