import 'package:flutter/material.dart';

import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class WhatsappConversationsTable extends StatefulWidget {
  const WhatsappConversationsTable({
    super.key,
    required this.messages,
  });

  final List<WhatsappMessage> messages;

  @override
  State<WhatsappConversationsTable> createState() => _WhatsappConversationsTableState();
}

class _WhatsappConversationsTableState extends State<WhatsappConversationsTable> {
  String _searchQuery = '';
  String _statusFilter = 'Todos';
  String _directionFilter = 'Todas';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Apenas filtros locais simples para UI
    final filteredMessages = widget.messages.where((m) {
      if (_searchQuery.isNotEmpty) {
        if (!m.contact.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            !m.phoneNumber.contains(_searchQuery) &&
            !m.preview.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      if (_statusFilter != 'Todos') {
        if (m.statusLabel != _statusFilter) return false;
      }
      if (_directionFilter != 'Todas') {
        if (_directionFilter == 'Enviadas' && !m.outbound) return false;
        if (_directionFilter == 'Recebidas' && m.outbound) return false;
      }
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FILTROS
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FILTRO INTELIGENTE (NOME, TEL OU MENSAGEM)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Pesquisar...',
                            hintStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                            prefixIcon: const Icon(Icons.search, color: AppColors.border),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                            ),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATUS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: _CustomDropdown(
                          value: _statusFilter,
                          items: const ['Todos', 'RECEBIDO', 'ENVIADO'],
                          onChanged: (v) => setState(() => _statusFilter = v!),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DIREÇÃO',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: _CustomDropdown(
                          value: _directionFilter,
                          items: const ['Todas', 'Enviadas', 'Recebidas'],
                          onChanged: (v) => setState(() => _directionFilter = v!),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _statusFilter = 'Todos';
                      _directionFilter = 'Todas';
                    });
                  },
                  child: Text(
                    'LIMPAR',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.border),
          
          // HEADER DA TABELA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(flex: 1, child: _TableHeaderText('DATA/HORA')),
                Expanded(flex: 3, child: _TableHeaderText('PACIENTE')),
                Expanded(flex: 1, child: _TableHeaderText('STATUS')),
                Expanded(flex: 4, child: _TableHeaderText('INTERAÇÃO')),
                SizedBox(width: 80, child: _TableHeaderText('AÇÕES', align: TextAlign.right)),
              ],
            ),
          ),
          
          Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.border),

          // LISTA DE MENSAGENS
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredMessages.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.border),
            itemBuilder: (context, index) {
              return _TableRow(message: filteredMessages[index]);
            },
          ),
        ],
      ),
    );
  }
}

class _CustomDropdown extends StatelessWidget {
  const _CustomDropdown({required this.value, required this.items, required this.onChanged});
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TableHeaderText extends StatelessWidget {
  const _TableHeaderText(this.text, {this.align = TextAlign.left});
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: AppColors.textTertiary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.message});
  final WhatsappMessage message;

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  String _formatDate(DateTime time) {
    const months = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
    final year = time.year.toString().substring(2);
    return "${time.day.toString().padLeft(2, '0')} ${months[time.month - 1]} $year";
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) return name.substring(0, 1).toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DATA/HORA
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(message.time),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  _formatDate(message.time),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          
          // PACIENTE
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
                  child: message.contact.contains('Allan') 
                    ? const Icon(Icons.person, color: Colors.blue) 
                    : Text(_getInitials(message.contact), style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.contact,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        message.phoneNumber,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // STATUS
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    message.statusLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // INTERAÇÃO
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.border),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        message.contextText ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.pinkAccent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        message.preview,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.pinkAccent,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // AÇÕES
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.more_horiz, color: AppColors.textTertiary),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
