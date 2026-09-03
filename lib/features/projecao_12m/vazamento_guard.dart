/// Guarda de vazamento — a coluna que faltava na tabela de dados era
/// **"disponível em"**.
///
/// Listar lado a lado, sem distinção, features que existem no momento da
/// predição e features que só existem depois produz um modelo excelente na
/// validação e impossível de servir: no instante em que o escore é necessário —
/// dias antes da consulta — `tempo_ate_confirmacao_horas` ainda não existe.
///
/// Pior ainda são `lembrete_enviado` e `quantidade_lembretes`: são variáveis de
/// **tratamento**, decididas pela própria intervenção que se quer avaliar.
/// Usá-las como preditor num modelo que depois orienta a intervenção fecha um
/// ciclo causal vicioso — o modelo aprende que quem recebe três lembretes falta
/// pouco, o escore cai, a intervenção é retirada, a falta volta a subir.
///
/// Vazamento não é detectado por revisão de código: ele aparece como uma
/// métrica boa demais, e métrica boa ninguém questiona. Um teste automatizado é
/// a única barreira que funciona — por isso esta guarda existe como código
/// executável e não como parágrafo de documentação.
library;

import 'package:flutter/foundation.dart';

/// Em que momento o valor de uma feature passa a existir.
enum Disponibilidade {
  /// Existe quando o agendamento é criado. Seguro para treino e para serviço.
  criacao(
    'Na criação',
    seguroParaTreino: true,
    seguroParaServico: true,
  ),

  /// Existe na criação, mas só se calculado com corte *as-of*: apenas
  /// desfechos anteriores à data do agendamento.
  corteAsOf(
    'Na criação, com corte as-of',
    seguroParaTreino: true,
    seguroParaServico: true,
  ),

  /// Muda ao longo do tempo. Só entra com snapshot do instante da predição.
  evolui(
    'Evolui — usar snapshot no instante da predição',
    seguroParaTreino: true,
    seguroParaServico: true,
  ),

  /// Decidida pela intervenção. Registrar sempre; **nunca** como preditor.
  tratamento(
    'Pós-decisão de intervenção — TRATAMENTO',
    seguroParaTreino: false,
    seguroParaServico: false,
  ),

  /// Só existe depois do fato. Serve para análise, nunca para treino.
  posFato(
    'Após o fato — PÓS-FATO',
    seguroParaTreino: false,
    seguroParaServico: false,
  ),

  /// O próprio alvo. Não é preditor de si mesmo.
  alvo(
    'Após a consulta — ALVO',
    seguroParaTreino: false,
    seguroParaServico: false,
  );

  const Disponibilidade(
    this.label, {
    required this.seguroParaTreino,
    required this.seguroParaServico,
  });

  final String label;
  final bool seguroParaTreino;
  final bool seguroParaServico;
}

/// Uma coluna da tabela de eventos, com a procedência declarada.
@immutable
class Feature {
  const Feature(this.nome, this.disponibilidade, this.uso);

  final String nome;
  final Disponibilidade disponibilidade;

  /// Para que serve — inclusive quando o "para que" é "só para análise".
  final String uso;

  bool get bloqueadaNoTreino => !disponibilidade.seguroParaTreino;
}

/// Uma coluna que não deveria estar onde está.
@immutable
class AchadoVazamento {
  const AchadoVazamento({
    required this.coluna,
    required this.disponibilidade,
    required this.motivo,
  });

  final String coluna;

  /// `null` quando a coluna não está no catálogo — desconhecida é suspeita.
  final Disponibilidade? disponibilidade;

  final String motivo;
}

/// Lançada quando um conjunto de treino contém coluna proibida.
class VazamentoDetectado implements Exception {
  VazamentoDetectado(this.achados);

  final List<AchadoVazamento> achados;

  @override
  String toString() => 'VazamentoDetectado: ${achados.length} coluna(s) '
      'proibida(s) no conjunto de treino\n'
      '${achados.map((a) => '  · ${a.coluna}: ${a.motivo}').join('\n')}';
}

/// Catálogo das colunas da tabela principal de eventos.
///
/// É a tabela da seção 3.1 transcrita em código. Mantê-la aqui — e não só no
/// documento — é o que permite que a guarda seja executável.
class CatalogoFeatures {
  const CatalogoFeatures._();

  static const List<Feature> colunas = [
    Feature('agendamento_id', Disponibilidade.criacao, 'chave do evento'),
    Feature('clinica_id', Disponibilidade.criacao, 'segmentação multi-tenant'),
    Feature('data_agendamento', Disponibilidade.criacao, 'tempo da decisão'),
    Feature('data_consulta', Disponibilidade.criacao, 'variável temporal'),
    Feature('canal_agendamento', Disponibilidade.criacao, 'feature'),
    Feature('dias_antecedencia', Disponibilidade.criacao, 'feature de risco'),
    Feature('especialidade', Disponibilidade.criacao, 'segmentação'),
    Feature('medico_id', Disponibilidade.criacao, 'segmentação'),
    Feature('unidade_id', Disponibilidade.criacao, 'segmentação'),
    Feature('valor_consulta', Disponibilidade.criacao, 'impacto financeiro'),
    Feature('capacidade_ofertada', Disponibilidade.criacao,
        'teto físico — sem ela a demanda observada é confundida com demanda'),
    Feature('tentativas_sem_vaga', Disponibilidade.criacao,
        'censura por capacidade'),
    Feature('historico_faltas', Disponibilidade.corteAsOf,
        'feature de risco — só desfechos anteriores ao agendamento'),
    Feature('historico_cancelamentos', Disponibilidade.corteAsOf,
        'feature de risco — idem'),
    Feature('confirmacao', Disponibilidade.evolui, 'estado intermediário'),
    Feature('canal_confirmacao', Disponibilidade.evolui,
        'feature — nulo até confirmar'),
    Feature('lembrete_enviado', Disponibilidade.tratamento,
        'registrar sempre para avaliar impacto; nunca como preditor'),
    Feature('quantidade_lembretes', Disponibilidade.tratamento,
        'registrar sempre para avaliar impacto; nunca como preditor'),
    Feature('canal_lembrete', Disponibilidade.tratamento,
        'registrar sempre para avaliar impacto; nunca como preditor'),
    Feature('tempo_ate_confirmacao_horas', Disponibilidade.posFato,
        'só para análise — não existe no momento da predição'),
    Feature('status_final', Disponibilidade.alvo, 'alvo / estado absorvente'),
  ];

  static final Map<String, Feature> _porNome = {
    for (final f in colunas) f.nome: f,
  };

  static Feature? de(String nome) => _porNome[nome.trim().toLowerCase()];

  static List<Feature> get deTratamento => colunas
      .where((f) => f.disponibilidade == Disponibilidade.tratamento)
      .toList();

  static List<Feature> get posFato => colunas
      .where((f) => f.disponibilidade == Disponibilidade.posFato)
      .toList();

  static List<Feature> get seguras =>
      colunas.where((f) => !f.bloqueadaNoTreino).toList();
}

/// A barreira: falha o build antes que a métrica ilusória convença alguém.
class GuardaVazamento {
  const GuardaVazamento._();

  /// Analisa um conjunto de colunas de treino e devolve o que está errado.
  ///
  /// Coluna fora do catálogo é reportada como **desconhecida**, não como
  /// aprovada: numa tabela de saúde, a coluna que ninguém classificou é
  /// exatamente onde o vazamento costuma entrar.
  static List<AchadoVazamento> analisar(Iterable<String> colunasDeTreino) {
    final achados = <AchadoVazamento>[];
    for (final bruta in colunasDeTreino) {
      final nome = bruta.trim().toLowerCase();
      if (nome.isEmpty) continue;
      final f = CatalogoFeatures.de(nome);

      if (f == null) {
        achados.add(AchadoVazamento(
          coluna: bruta,
          disponibilidade: null,
          motivo: 'coluna fora do catálogo — classifique a disponibilidade '
              'antes de treinar com ela',
        ));
        continue;
      }
      if (f.bloqueadaNoTreino) {
        achados.add(AchadoVazamento(
          coluna: bruta,
          disponibilidade: f.disponibilidade,
          motivo: switch (f.disponibilidade) {
            Disponibilidade.tratamento =>
              'variável de TRATAMENTO: usá-la como preditor do risco que ela '
                  'mesma altera fecha um ciclo causal vicioso',
            Disponibilidade.posFato =>
              'variável PÓS-FATO: não existe no momento da predição, o modelo '
                  'fica impossível de servir',
            Disponibilidade.alvo =>
              'é o próprio alvo — treinar com ela produz acerto perfeito e '
                  'zero informação',
            _ => 'bloqueada no treino',
          },
        ));
      }
    }
    return achados;
  }

  /// Igual a [analisar], mas lança. É a forma para usar em teste de CI.
  static void exigirLimpo(Iterable<String> colunasDeTreino) {
    final achados = analisar(colunasDeTreino);
    if (achados.isNotEmpty) throw VazamentoDetectado(achados);
  }

  static bool limpo(Iterable<String> colunasDeTreino) =>
      analisar(colunasDeTreino).isEmpty;

  /// Remove do conjunto o que não pode entrar, devolvendo o que sobrou.
  ///
  /// Use ao montar a tabela de treino a partir de um esquema amplo. O descarte
  /// é silencioso de propósito no valor de retorno, mas [analisar] continua
  /// disponível para relatar o que saiu.
  static List<String> filtrar(Iterable<String> colunas) => [
        for (final c in colunas)
          if (CatalogoFeatures.de(c)?.bloqueadaNoTreino == false) c,
      ];
}
