import '../../ia/agent/ai_agent_service.dart';
import 'plano_semanal.dart';
import 'validador_numeros.dart';

/// Agente que interpreta o plano de encaixes.
///
/// ## O que ele automatiza
///
/// Hoje o gestor abre o simulador, escolhe uma data, lê a aba de decisão,
/// anota, avança um dia e repete — cinco a sete vezes por semana. O agente faz
/// a varredura de uma vez e entrega o que sobra de trabalho humano: **onde
/// olhar primeiro e por quê**.
///
/// ## O que ele NÃO faz — e as três travas que garantem isso
///
/// **1. Não calcula.** Os números todos vêm de [ExecutorPlano], que é
/// determinístico e reprodutível. O modelo recebe o resultado pronto.
///
/// **2. Não aplica.** A saída é [SugestaoPlano] — uma sugestão. Nada é gravado
/// na agenda; encaixar é ação do gestor, num segundo passo explícito. É a
/// mesma regra do Vigia (`.specify/VIGIA.md`): rotina de IA nasce como
/// proposta, nunca como execução.
///
/// **3. Não passa sem conferência.** [ValidadorNumeros] checa cada cifra do
/// texto contra a simulação e marca o que não bate.
///
/// Sem as três, um texto fluente e errado vira gente a mais numa sala de
/// espera real.
class AgenteSimulacao {
  AgenteSimulacao({
    required AiAgentService ia,
    this.validador = const ValidadorNumeros(),
  }) : _ia = ia;

  final AiAgentService _ia;
  final ValidadorNumeros validador;

  /// Interpreta o [plano]. Falha de IA **não** invalida o plano: a tela mostra
  /// os números do mesmo jeito, sem a leitura.
  Future<SugestaoPlano> interpretar(PlanoSemanal plano) async {
    if (plano.vazio || plano.comAgenda.isEmpty) {
      return SugestaoPlano.semAgenda(plano);
    }

    try {
      final texto = await _ia.runToString(
        prompt: '${_prompt()}\n\n${plano.paraPrompt()}',
        toolSpecs: const [],
        callTool: (nome, args) async => (text: '', isError: false),
        clinicaId: '',
      );
      final v = validador.validar(texto, plano.numerosPermitidos);
      return SugestaoPlano(
        plano: plano,
        analise: validador.anotar(texto.trim(), v),
        validacao: v,
      );
    } catch (e) {
      return SugestaoPlano.semIa(plano, '$e');
    }
  }

  String _prompt() => '''
Você analisa um plano de encaixes de uma clínica, já calculado por uma
simulação de Monte Carlo. Escreva em português, para o gestor da agenda.

REGRA ABSOLUTA — NÃO INVENTE NÚMEROS
Use SOMENTE os números que aparecem no plano abaixo. Não some, não calcule
média, não estime, não arredonde para um valor que não está escrito. Toda
cifra do seu texto é conferida automaticamente contra a simulação, e o que não
bater aparece marcado com ⚠️ na tela do gestor.

Se quiser falar de algo que o plano não traz, descreva sem número
("a maior parte dos dias", "poucos slots").

O QUE ESCREVER (markdown, curto — o gestor lê isto entre atendimentos):

**O essencial** — 2 a 3 frases: quantos encaixes a semana comporta e onde está
a oportunidade ou o problema.

**Onde olhar primeiro** — lista dos dias que pedem atenção, cada um com o
motivo em uma linha. Dia tranquilo não entra na lista.

**Risco a acompanhar** — o que pode dar errado neste plano. Se a simulação
mostra folga em toda a semana, diga que o risco é baixo em vez de inventar
preocupação.

TOM
Direto e operacional. Sem preâmbulo, sem repetir o enunciado, sem oferecer
ajuda no fim. O gestor decide; você informa.

O QUE NUNCA ESCREVER
- Nada que soe como ordem executada ("agendei", "encaixei", "liberei"). Você
  sugere; quem aplica é o gestor.
- Recomendação de encaixar acima do que a simulação aprovou.''';
}

/// Resultado da interpretação — sempre com o plano junto.
class SugestaoPlano {
  const SugestaoPlano({
    required this.plano,
    required this.analise,
    this.validacao,
    this.erroIa,
  });

  /// A IA não foi chamada porque não havia agenda a analisar.
  factory SugestaoPlano.semAgenda(PlanoSemanal plano) => SugestaoPlano(
        plano: plano,
        analise: 'Nenhum dia da janela tem agenda. Não há o que planejar.',
      );

  /// A IA falhou. Os números continuam válidos e visíveis.
  factory SugestaoPlano.semIa(PlanoSemanal plano, String erro) => SugestaoPlano(
        plano: plano,
        analise: '',
        erroIa: erro,
      );

  final PlanoSemanal plano;

  /// Texto da IA, já com os números duvidosos marcados.
  final String analise;

  final ResultadoNumeros? validacao;
  final String? erroIa;

  bool get temAnalise => analise.trim().isNotEmpty;
  bool get falhouIa => erroIa != null;

  /// `true` quando todos os números do texto vieram da simulação.
  bool get numerosConferem => validacao?.ok ?? true;
}
