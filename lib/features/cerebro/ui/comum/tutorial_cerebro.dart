import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'cerebro_ui.dart';

/// Abre o tutorial interativo do Cérebro.
Future<void> mostrarTutorialCerebro(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _DialogoTutorialCerebro(),
  );
}

class _DialogoTutorialCerebro extends StatefulWidget {
  const _DialogoTutorialCerebro();

  @override
  State<_DialogoTutorialCerebro> createState() => _DialogoTutorialCerebroState();
}

class _DialogoTutorialCerebroState extends State<_DialogoTutorialCerebro> {
  int _passoAtual = 0;

  static const _passos = <_PassoTutorial>[
    _PassoTutorial(
      titulo: 'Bem-vindo ao Cérebro Vitta',
      subtitulo: 'O Segundo Cérebro e Memória Central da sua Clínica',
      icone: Icons.psychology_outlined,
      corIcone: Color(0xFFF43F5E),
      topicos: [
        _Topico(
          titulo: 'O que é o Cérebro?',
          descricao:
              'Diferente de pastas tradicionais e arquivos soltos, o Cérebro '
              'funciona como uma rede neural: cada nota se conecta a outras, '
              'formando uma base de conhecimento viva e inteligente.',
          icone: Icons.hub_outlined,
        ),
        _Topico(
          titulo: 'Tudo em um só lugar',
          descricao:
              'Centralize protocolos médicos, rotinas operacionais, reuniões, '
              'padrões de conduta e diários de bordo para toda a equipe.',
          icone: Icons.folder_special_outlined,
        ),
      ],
    ),
    _PassoTutorial(
      titulo: 'Criando e Conectando Conhecimento',
      subtitulo: 'A mágica dos Wikilinks [[...]] e Tags #...',
      icone: Icons.edit_note_outlined,
      corIcone: Color(0xFF38BDF8),
      topicos: [
        _Topico(
          titulo: 'Conecte notas com [[Wikilinks]]',
          descricao:
              'No editor de texto, digite [[ para abrir o autocompletar e ligar '
              'qualquer assunto. Exemplo: [[Protocolo de Hipertensão]]. '
              'Cada link gera uma linha viva no Grafo!',
          icone: Icons.link,
        ),
        _Topico(
          titulo: 'Categorize com #Tags e @Entidades',
          descricao:
              'Use #tag (#cirurgia, #gestao) para agrupar temas e @entidade '
              '(@medico:dr_silva, @paciente:123) para integrar com o sistema.',
          icone: Icons.tag,
        ),
      ],
    ),
    _PassoTutorial(
      titulo: 'Explorando o Grafo Visual (Graph View)',
      subtitulo: 'Navegue visualmente pelas ideias da clínica',
      icone: Icons.bubble_chart_outlined,
      corIcone: Color(0xFF10B981),
      topicos: [
        _Topico(
          titulo: 'Formas e Conexões',
          descricao:
              'Bolinhas são notas (quanto mais links, maior o nó); '
              'Quadrados são tags; Losangos são entidades da clínica. '
              'As setas indicam o sentido das relações.',
          icone: Icons.category_outlined,
        ),
        _Topico(
          titulo: 'Navegação e Tela Cheia (F11)',
          descricao:
              'Use o scroll para zoom, arraste os nós para organizar e dê dois '
              'cliques para abrir no editor. Pressione F11 para tela cheia imersiva.',
          icone: Icons.fullscreen,
        ),
      ],
    ),
    _PassoTutorial(
      titulo: 'Buscas Inteligentes no Grafo',
      subtitulo: 'Busca Normal em tempo real ou com Agente IA',
      icone: Icons.search_outlined,
      corIcone: Color(0xFFF59E0B),
      topicos: [
        _Topico(
          titulo: 'Busca Normal (Spotlight Dourado)',
          descricao:
              'Filtre rapidamente por palavras-chave, #tags ou tipos. '
              'As notas encontradas brilham com halo dourado e as outras '
              'ficam esmaecidas.',
          icone: Icons.filter_alt_outlined,
        ),
        _Topico(
          titulo: 'Busca com Agente IA (DeepSeek)',
          descricao:
              'Pergunte em linguagem natural (ex.: "notas sobre absenteísmo '
              'cirúrgico"). O agente analisa a rede semântica e explica seu raciocínio.',
          icone: Icons.auto_awesome,
        ),
      ],
    ),
    _PassoTutorial(
      titulo: 'Como a I.A. Utiliza o Cérebro?',
      subtitulo: 'Seu copiloto de gestão com contexto total da clínica',
      icone: Icons.auto_awesome,
      corIcone: Color(0xFF8B5CF6),
      topicos: [
        _Topico(
          titulo: 'Respostas com Contexto Real',
          descricao:
              'A IA do Vitta Care lê os protocolos do Cérebro para responder dúvidas '
              'e dar recomendações precisas e personalizadas à sua clínica.',
          icone: Icons.psychology,
        ),
        _Topico(
          titulo: 'Notas Escritas pela IA (Anel Violeta 🟣)',
          descricao:
              'O agente pode sugerir análises e diagnósticos operacionais. '
              'Notas escritas pela IA recebem um anel violeta no grafo para fácil identificação.',
          icone: Icons.lightbulb_outlined,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final passo = _passos[_passoAtual];
    final ehUltimo = _passoAtual == _passos.length - 1;

    return Dialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho do modal
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: passo.corIcone.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: passo.corIcone.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(passo.icone, size: 24, color: passo.corIcone),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passo.titulo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        passo.subtitulo,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Fechar',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Barra de progresso dos passos
            Row(
              children: [
                for (var i = 0; i < _passos.length; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _passoAtual
                            ? passo.corIcone
                            : AppColors.borderOf(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < _passos.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Conteúdo dos tópicos do passo
            Expanded(
              child: ListView(
                children: [
                  for (final topico in passo.topicos)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: CerebroTokens.trilho(context),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: AppColors.borderOf(context).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: passo.corIcone.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(topico.icone,
                                size: 18, color: passo.corIcone),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topico.titulo,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  topico.descricao,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Rodapé com ações de navegação
            Row(
              children: [
                Text(
                  'Passo  de ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
                const Spacer(),
                if (_passoAtual > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _passoAtual--),
                    child: const Text('Anterior'),
                  ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () {
                    if (ehUltimo) {
                      Navigator.pop(context);
                    } else {
                      setState(() => _passoAtual++);
                    }
                  },
                  child: Text(ehUltimo ? 'Começar a Usar 🚀' : 'Próximo →'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PassoTutorial {
  const _PassoTutorial({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.corIcone,
    required this.topicos,
  });

  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color corIcone;
  final List<_Topico> topicos;
}

class _Topico {
  const _Topico({
    required this.titulo,
    required this.descricao,
    required this.icone,
  });

  final String titulo;
  final String descricao;
  final IconData icone;
}
