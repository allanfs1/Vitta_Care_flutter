import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ia/agent/ai_agent_service.dart';
import '../monte_carlo_calibracao.dart';
import '../monte_carlo_providers.dart';
import 'acoes_ia.dart';
import 'mc_ia_providers.dart';
import 'validador_numeros.dart';

/// Resultado de uma ação de IA.
@immutable
class RespostaAcao {
  const RespostaAcao({
    required this.acaoId,
    required this.texto,
    required this.validacao,
    required this.em,
    this.erro,
  });

  final String acaoId;

  /// Texto já anotado: cifra que não veio da simulação leva ⚠️.
  final String texto;

  final ResultadoNumeros? validacao;
  final DateTime em;
  final String? erro;

  bool get falhou => erro != null;
  bool get temAviso => validacao != null && !validacao!.ok;

  String? get aviso =>
      validacao == null ? null : const ValidadorNumeros().aviso(validacao!);
}

/// Estado da aba de ações: qual está rodando e o que já foi respondido.
@immutable
class EstadoAcoes {
  const EstadoAcoes({
    this.rodando,
    this.respostas = const {},
    this.indisponiveis = const {},
  });

  /// Id da ação em execução, ou `null`.
  final String? rodando;

  /// Última resposta de cada ação, por id. Guardar todas permite comparar
  /// leituras sem refazer a chamada.
  final Map<String, RespostaAcao> respostas;

  /// Ações que o estado atual da tela não permite, com o motivo.
  final Map<String, String> indisponiveis;

  EstadoAcoes copyWith({
    String? rodando,
    bool limparRodando = false,
    Map<String, RespostaAcao>? respostas,
    Map<String, String>? indisponiveis,
  }) =>
      EstadoAcoes(
        rodando: limparRodando ? null : (rodando ?? this.rodando),
        respostas: respostas ?? this.respostas,
        indisponiveis: indisponiveis ?? this.indisponiveis,
      );
}

/// Executa as ações do catálogo.
///
/// Uma ação por vez, de propósito: são chamadas de LLM sobre a mesma tela, e
/// deixar o gestor disparar cinco em paralelo produziria cinco esperas
/// simultâneas sem que nenhuma leitura ficasse pronta antes.
class AcoesController extends StateNotifier<EstadoAcoes> {
  AcoesController(this._ref) : super(const EstadoAcoes());

  final Ref _ref;
  static const _montador = MontadorContexto();
  static const _validador = ValidadorNumeros();

  /// Por que uma ação não pode rodar agora — `null` se pode.
  String? indisponivel(AcaoIa acao) {
    final r = _ref.read(mcResultadoProvider).valueOrNull;

    if (acao.exigeAgenda) {
      if (r == null) return 'A simulação do dia ainda não terminou.';
      if (r.totalAgendados == 0) {
        return 'Sem consultas nesta data — escolha outro dia.';
      }
    }
    if (acao.id == 'mensagem_fila' && (r?.fila.chamadasSeguras ?? 0) <= 0) {
      return 'Nenhuma vaga liberada com antecedência nesta data.';
    }
    if (acao.exigeCalibracao) {
      final c = _ref.read(mcCalibracaoProvider).valueOrNull;
      if (c == null) return 'A calibração ainda não terminou.';
    }
    return null;
  }

  Future<void> executar(String acaoId) async {
    if (state.rodando != null) return;

    final acao = AcaoIa.porId(acaoId);
    if (acao == null) return;

    final motivo = indisponivel(acao);
    if (motivo != null) {
      state = state.copyWith(
        indisponiveis: {...state.indisponiveis, acaoId: motivo},
      );
      return;
    }

    state = state.copyWith(rodando: acaoId);

    try {
      final contexto = _montador.montar(
        acaoId: acaoId,
        resultado: _ref.read(mcResultadoProvider).valueOrNull,
        calibracao: _ref.read(mcCalibracaoProvider).valueOrNull,
        cenarios: _ref.read(mcCenariosProvider),
        encaixesRecomendados: _ref.read(mcEncaixesRecomendadosProvider),
        limiteRisco: _ref.read(mcLimiteRiscoProvider),
      );

      if (contexto == null) {
        state = state.copyWith(
          limparRodando: true,
          respostas: {
            ...state.respostas,
            acaoId: RespostaAcao(
              acaoId: acaoId,
              texto: '',
              validacao: null,
              em: DateTime.now(),
              erro: 'Não há dados suficientes para esta leitura.',
            ),
          },
        );
        return;
      }

      final ia = _ref.read(mcIaServiceProvider);
      final texto = await ia.runToString(
        prompt: contexto.prompt,
        toolSpecs: const [],
        // Estas ações não usam ferramenta: o contexto já vem pronto. É o que
        // garante que o modelo interpreta em vez de consultar.
        callTool: (nome, args) async => (text: '', isError: false),
        clinicaId: '',
      );

      final v = _validador.validar(texto, contexto.numerosPermitidos);
      state = state.copyWith(
        limparRodando: true,
        respostas: {
          ...state.respostas,
          acaoId: RespostaAcao(
            acaoId: acaoId,
            texto: _validador.anotar(texto.trim(), v),
            validacao: v,
            em: DateTime.now(),
          ),
        },
      );
    } catch (e) {
      state = state.copyWith(
        limparRodando: true,
        respostas: {
          ...state.respostas,
          acaoId: RespostaAcao(
            acaoId: acaoId,
            texto: '',
            validacao: null,
            em: DateTime.now(),
            erro: '$e',
          ),
        },
      );
    }
  }

  void limpar(String acaoId) {
    final novas = {...state.respostas}..remove(acaoId);
    state = state.copyWith(respostas: novas);
  }

  void limparTudo() => state = const EstadoAcoes();
}

final mcAcoesProvider =
    StateNotifierProvider<AcoesController, EstadoAcoes>(
        AcoesController.new);

/// Serviço de IA usado pelas ações. Separado para o teste poder trocar.
final mcIaServiceProvider = Provider<AiAgentService>((ref) => AiAgentService());
