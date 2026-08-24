import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/nota.dart';
import '../../data/models/nota_enums.dart';

/// Selo de proveniência da nota (`obsidian.md` §10.4 › barra de contexto).
///
/// Torna visível, de relance, o que foi escrito por gente e o que foi escrito
/// pela IA — e com que confiança. É a peça de UI que sustenta o princípio P5
/// (escrita do agente auditável).
class BadgeOrigem extends StatelessWidget {
  const BadgeOrigem({super.key, required this.nota, this.compacto = false});

  final Nota nota;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final itens = <Widget>[];

    if (nota.ehDeAgente) {
      final conf = nota.confianca;
      final cor = conf == null
          ? const Color(0xFF7C3AED)
          : conf >= 0.85
              ? AppColors.success
              : conf >= 0.6
                  ? AppColors.warning
                  : AppColors.danger;
      itens.add(_pilula(
        context,
        icone: Icons.auto_awesome,
        texto: conf == null ? 'IA' : 'IA ${conf.toStringAsFixed(2)}',
        cor: cor,
      ));
    }

    if (nota.ehRascunho) {
      itens.add(_pilula(
        context,
        icone: Icons.edit_note,
        texto: 'rascunho',
        cor: AppColors.warning,
      ));
    } else if (nota.revisada) {
      itens.add(_pilula(
        context,
        icone: Icons.verified_outlined,
        texto: 'revisada',
        cor: AppColors.success,
      ));
    }

    if (nota.arquivada) {
      itens.add(_pilula(
        context,
        icone: Icons.inventory_2_outlined,
        texto: 'arquivada',
        cor: AppColors.textSecondaryOf(context),
      ));
    }

    if (nota.sensivel) {
      itens.add(_pilula(
        context,
        icone: Icons.lock_outline,
        texto: 'sensível',
        cor: AppColors.danger,
      ));
    }

    if (itens.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 4, runSpacing: 4, children: itens);
  }

  Widget _pilula(
    BuildContext context, {
    required IconData icone,
    required String texto,
    required Color cor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacto ? 4 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 10, color: cor),
          if (!compacto) ...[
            const SizedBox(width: 3),
            Text(
              texto,
              style: TextStyle(fontSize: 10, color: cor, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ícone do tipo da nota, com a cor da paleta do grafo (§10.5.3).
class NotaIcone extends StatelessWidget {
  const NotaIcone({super.key, required this.tipo, this.tamanho = 15});

  final NotaTipo tipo;
  final double tamanho;

  @override
  Widget build(BuildContext context) =>
      Icon(tipo.icon, size: tamanho, color: tipo.cor);
}
