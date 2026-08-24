import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../models/announcement.dart';
import '../../recepcao_provider.dart';

class MuralClinicaTab extends ConsumerWidget {
  const MuralClinicaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recepcaoProvider);
    final theme = Theme.of(context);
    final announcements = state.announcements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mural de Avisos da Unidade', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFFE65100))),
                    const SizedBox(height: 4),
                    Text('GERENCIE AS COMUNICAÇÕES INTERNAS PARA OS ATENDENTES.', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('CRIAR AVISO'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.white),
              )
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: announcements.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: Text('Nenhum aviso no momento.')),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            headingTextStyle:
                                theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            dataRowMaxHeight: 80,
                            dataRowMinHeight: 80,
                            columnSpacing: AppSpacing.md,
                            columns: const [
                              DataColumn(label: Text('DATA/HORA')),
                              DataColumn(label: Text('AUTOR')),
                              DataColumn(label: Text('MENSAGEM')),
                              DataColumn(label: Text('AÇÕES')),
                            ],
                            rows: announcements
                                .map((a) => _buildRow(theme, a, ref))
                                .toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  DataRow _buildRow(ThemeData theme, Announcement announcement, WidgetRef ref) {
    return DataRow(
      cells: [
        DataCell(
          Text('${announcement.createdAt.day.toString().padLeft(2, '0')}/${announcement.createdAt.month.toString().padLeft(2, '0')} às ${announcement.createdAt.hour.toString().padLeft(2, '0')}:${announcement.createdAt.minute.toString().padLeft(2, '0')}', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFE0B2)),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            child: Text(
              announcement.author,
              style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFFE65100), fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 400,
            child: Text(announcement.message, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(
          IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30), size: 20), onPressed: () => ref.read(recepcaoProvider.notifier).deleteAnnouncement(announcement.id)),
        ),
      ],
    );
  }
}
