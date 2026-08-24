import 'dart:math' as math;

import 'models/nota.dart';
import 'models/nota_enums.dart';

/// Gerador de vault sintético para exercitar a interface do Cérebro com
/// volume realista (`obsidian.md` §18.3 › `vault_medio`).
///
/// Características do vault gerado — são elas que fazem o teste valer:
///  - **Distribuição de links em lei de potência**: poucos MOCs concentram a
///    maior parte das entradas, como num vault real. Sem isso o grafo vira
///    uma malha uniforme e nada se aprende sobre LOD, PageRank ou clusters.
///  - **Estrutura temporal**: notas diárias encadeadas cronologicamente,
///    que é o que dá "espinha dorsal" ao grafo.
///  - **Entidades operacionais** (`@medico`, `@paciente`, `@score`…) para
///    exercitar a ponte e as cores por tipo.
///  - **Imperfeições propositais**: órfãs, links quebrados, rascunhos da IA
///    com confiança baixa e notas sensíveis — os estados que a UI precisa
///    saber mostrar.
///
/// Determinístico: mesma `seed` produz exatamente o mesmo vault, para que
/// comparações de performance entre execuções sejam legítimas.
class VaultDemo {
  VaultDemo._();

  /// Gera [alvo] notas (aproximado — o gerador arredonda por categoria).
  static List<Nota> gerar(
    String clinicaId, {
    int alvo = 1200,
    int seed = 42,
    DateTime? referencia,
  }) {
    final rnd = math.Random(seed);
    final hoje = referencia ?? DateTime.now();
    final notas = <Nota>[];
    var seq = 0;

    String proximoId() => 'nt_demo_${(seq++).toString().padLeft(5, '0')}';

    // Proporções calibradas para parecer um vault de clínica com 1 ano de uso.
    final nDiarias = (alvo * 0.30).round();
    final nAnalises = (alvo * 0.22).round();
    final nConceitos = (alvo * 0.14).round();
    final nProtocolos = (alvo * 0.08).round();
    final nPadroes = (alvo * 0.08).round();
    final nDecisoes = (alvo * 0.05).round();
    final nReunioes = (alvo * 0.05).round();
    final nFontes = (alvo * 0.04).round();
    final nPessoas = (alvo * 0.02).round();

    // ── 1 · MOCs (os hubs do grafo) ─────────────────────────────────────────
    final mocs = <_Ref>[];
    for (final m in _mocs) {
      final id = proximoId();
      mocs.add(_Ref(id, m.$1, 'mocs/${m.$2}.md'));
    }

    // ── 2 · Títulos das demais categorias (criados antes do conteúdo, para
    //        que os links sempre resolvam) ─────────────────────────────────
    final conceitos = _serie(nConceitos, proximoId, (i) {
      final t = '${_pick(_temas, rnd)} ${_pick(_qualificadores, rnd)}';
      return (t, 'conceitos/${_slug(t)}-$i.md');
    });
    final protocolos = _serie(nProtocolos, proximoId, (i) {
      final t = 'Protocolo de ${_pick(_processos, rnd)} ${_pick(_escopos, rnd)}';
      return (t, 'protocolos/${_slug(t)}-$i.md');
    });
    final padroes = _serie(nPadroes, proximoId, (i) {
      final t = 'Padrão · ${_pick(_padroesTexto, rnd)}';
      return (t, 'padroes/${_slug(t)}-$i.md');
    });
    final analises = _serie(nAnalises, proximoId, (i) {
      final t = 'Análise · ${_pick(_temas, rnd)} ${_pick(_recortes, rnd)}';
      return (t, 'agente/analises/${_slug(t)}-$i.md');
    });
    final decisoes = _serie(nDecisoes, proximoId, (i) {
      final t = 'Decisão · ${_pick(_decisoesTexto, rnd)}';
      return (t, 'decisoes/${_slug(t)}-$i.md');
    });
    final reunioes = _serie(nReunioes, proximoId, (i) {
      final d = hoje.subtract(Duration(days: i * 7 + 2));
      final t = 'Reunião ${_iso(d)}';
      return (t, 'reunioes/${_iso(d)}.md');
    });
    final fontes = _serie(nFontes, proximoId, (i) {
      final t = '${_pick(_fontesTexto, rnd)} (${2019 + rnd.nextInt(7)})';
      return (t, 'fontes/${_slug(t)}-$i.md');
    });
    final pessoas = _serie(nPessoas, proximoId, (i) {
      final t = '${_pick(_papeis, rnd)} · Perfil ${i + 1}';
      return (t, 'pessoas/${_slug(t)}-$i.md');
    });
    final diarias = <_Ref>[];
    for (var i = 0; i < nDiarias; i++) {
      final d = hoje.subtract(Duration(days: i));
      diarias.add(_Ref(proximoId(), _iso(d), 'diario/${_iso(d)}.md'));
    }

    // Pool de destinos ponderado: MOCs entram várias vezes → viram hubs.
    final pool = <_Ref>[
      ...mocs, ...mocs, ...mocs, ...mocs, ...mocs, ...mocs,
      ...protocolos, ...protocolos,
      ...conceitos,
      ...padroes,
      ...decisoes,
      ...analises,
      ...fontes,
      ...pessoas,
    ];

    /// Escolhe um destino com viés para o começo do pool (lei de potência).
    _Ref alvoLink() {
      final u = rnd.nextDouble();
      final i = (math.pow(u, 2.2) * pool.length).floor().clamp(0, pool.length - 1);
      return pool[i];
    }

    String links(int n, {String separador = ' · '}) {
      final vistos = <String>{};
      final out = <String>[];
      for (var i = 0; i < n * 2 && out.length < n; i++) {
        final a = alvoLink();
        if (!vistos.add(a.id)) continue;
        out.add('[[${a.titulo}]]');
      }
      return out.join(separador);
    }

    /// Entity-links coerentes: o prefixo do id acompanha o tipo, como nas
    /// coleções operacionais reais (med_44, pac_812…).
    String entidades(int n) {
      const tipos = <String>[
        'medico', 'paciente', 'agendamento', 'score', 'overbooking', 'alerta',
      ];
      final out = <String>[];
      for (var i = 0; i < n; i++) {
        final tipo = _pick(tipos, rnd);
        final prefixo = tipo.substring(0, 3);
        out.add('[[@$tipo:${prefixo}_${100 + rnd.nextInt(900)}]]');
      }
      return out.join(' · ');
    }

    String tags(int n) => {
          for (var i = 0; i < n; i++) '#${_pick(_tags, rnd)}',
        }.join(' ');

    // ── 3 · Conteúdo ────────────────────────────────────────────────────────

    for (final m in mocs) {
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: m,
        tipo: NotaTipo.moc,
        fixada: true,
        criadaEm: hoje.subtract(Duration(days: 300 + rnd.nextInt(60))),
        conteudo: '''
---
aliases: [${m.titulo.split(' ').first}]
tipo: moc
tags: [moc, ${_pick(_tags, rnd)}]
---

# ${m.titulo}

Mapa de conteúdo. Sobe de [[000 · Início]].

## Panorama

${links(6)}

## Normas e protocolos

${links(5, separador: '\n- ')}

## Em análise

${links(8, separador: '\n- ')}

## Entidades envolvidas

${entidades(4)}

${tags(3)}
''',
      ));
    }

    // Nota raiz que amarra tudo.
    notas.add(_montar(
      clinicaId: clinicaId,
      ref: _Ref(proximoId(), '000 · Início', '000-inicio.md'),
      tipo: NotaTipo.moc,
      fixada: true,
      criadaEm: hoje.subtract(const Duration(days: 365)),
      conteudo: '''
---
aliases: [Início, Home]
tipo: moc
tags: [moc, inicio]
---

# 000 · Início

Porta de entrada do Cérebro.

## Mapas

${mocs.map((m) => '- [[${m.titulo}]]').join('\n')}

## Hoje

- [[${_iso(hoje)}]]
''',
    ));

    for (final c in conceitos) {
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: c,
        tipo: NotaTipo.conceito,
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(340))),
        conteudo: '''
---
tipo: conceito
tags: [conceito, ${_pick(_tags, rnd)}]
---

# ${c.titulo}

${_paragrafo(rnd)}

## Por que importa

${_paragrafo(rnd)}

Relacionado: ${links(2 + rnd.nextInt(4))}

${tags(2)}
''',
      ));
    }

    for (final p in protocolos) {
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: p,
        tipo: NotaTipo.protocolo,
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(320))),
        revisadoPor: rnd.nextDouble() < 0.7 ? 'usr_gestor' : null,
        conteudo: '''
---
tipo: protocolo
tags: [protocolo, ${_pick(_tags, rnd)}]
status: vigente
---

# ${p.titulo}

> [!protocolo] Norma vigente
> Alterações só por decisão humana registrada.

## Regra

1. ${_paragrafo(rnd)}
2. ${_paragrafo(rnd)}
3. ${_paragrafo(rnd)}

## Quando falha

- ${_paragrafo(rnd)}
- ${_paragrafo(rnd)}

Relacionado: ${links(3 + rnd.nextInt(3))}
Entidades: ${entidades(2)}

${tags(2)}
''',
      ));
    }

    for (final p in padroes) {
      final conf = 0.62 + rnd.nextDouble() * 0.37;
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: p,
        tipo: NotaTipo.analise,
        origem: NotaOrigem.agente,
        confianca: conf,
        estado: conf >= 0.85 ? NotaEstado.publicada : NotaEstado.rascunho,
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(200))),
        conteudo: '''
---
tipo: analise
tags: [padrao, ${_pick(_tags, rnd)}]
---

# ${p.titulo}

> [!insight] Achado
> ${_paragrafo(rnd)}

## Evidência

${links(4 + rnd.nextInt(5), separador: '\n- ')}

## Contra-evidência

${_paragrafo(rnd)}

Entidades: ${entidades(3)}

${tags(2)}
''',
      ));
    }

    for (final a in analises) {
      final conf = 0.55 + rnd.nextDouble() * 0.44;
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: a,
        tipo: NotaTipo.analise,
        origem: NotaOrigem.agente,
        confianca: conf,
        estado: conf >= 0.85 ? NotaEstado.publicada : NotaEstado.rascunho,
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(180))),
        conteudo: '''
---
tipo: analise
tags: [analise, ${_pick(_tags, rnd)}]
---

# ${a.titulo}

${_paragrafo(rnd)}

## Números

| Indicador | Valor | vs. média |
|---|---:|---:|
| ${_pick(_indicadores, rnd)} | ${10 + rnd.nextInt(90)} | ${rnd.nextBool() ? '+' : '−'}${rnd.nextInt(40)}% |
| ${_pick(_indicadores, rnd)} | ${10 + rnd.nextInt(90)} | ${rnd.nextBool() ? '+' : '−'}${rnd.nextInt(40)}% |

## Leitura

${_paragrafo(rnd)}

Relacionado: ${links(2 + rnd.nextInt(4))}
Entidades: ${entidades(2)}

${tags(2)}
''',
      ));
    }

    for (final d in decisoes) {
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: d,
        tipo: NotaTipo.decisao,
        revisadoPor: 'usr_gestor',
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(300))),
        conteudo: '''
---
tipo: decisao
tags: [decisao, ${_pick(_tags, rnd)}]
---

# ${d.titulo}

> [!decisao] Decidido
> ${_paragrafo(rnd)}

## Contexto

${_paragrafo(rnd)}

## Alternativas descartadas

- ${_paragrafo(rnd)}

Base: ${links(3)}

${tags(2)}
''',
      ));
    }

    for (final r in reunioes) {
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: r,
        tipo: NotaTipo.reuniao,
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(300))),
        conteudo: '''
---
tipo: reuniao
tags: [reuniao]
---

# ${r.titulo}

## Pauta

${links(3, separador: '\n- ')}

## Encaminhamentos

- [ ] ${_paragrafo(rnd)}
- [x] ${_paragrafo(rnd)}

Participantes: ${entidades(3)}
''',
      ));
    }

    for (final f in fontes) {
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: f,
        tipo: NotaTipo.fonte,
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(360))),
        conteudo: '''
---
tipo: fonte
tags: [fonte]
---

# ${f.titulo}

${_paragrafo(rnd)}

## O que aproveitamos

${links(2)}
''',
      ));
    }

    for (final p in pessoas) {
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: p,
        tipo: NotaTipo.pessoa,
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(300))),
        conteudo: '''
---
tipo: pessoa
tags: [equipe]
---

# ${p.titulo}

${_paragrafo(rnd)}

Atua em: ${links(2)}
Entidade: ${entidades(1)}
''',
      ));
    }

    // Diárias — a espinha dorsal temporal.
    for (var i = 0; i < diarias.length; i++) {
      final d = diarias[i];
      final anterior = i + 1 < diarias.length ? diarias[i + 1] : null;
      final seguinte = i > 0 ? diarias[i - 1] : null;
      final faltas = rnd.nextInt(9);
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: d,
        tipo: NotaTipo.diario,
        origem: NotaOrigem.sistema,
        criadaEm: hoje.subtract(Duration(days: i)),
        conteudo: '''
---
tipo: diario
data: ${d.titulo}
tags: [diario, operacao]
---

# ${d.titulo}

${anterior != null ? '← [[${anterior.titulo}]]' : ''} ${seguinte != null ? '· [[${seguinte.titulo}]] →' : ''} · [[000 · Início]]

## Números do dia

| Indicador | Valor |
|---|---:|
| Consultas realizadas | ${25 + rnd.nextInt(35)} |
| Faltas | $faltas |
| Cancelamentos | ${rnd.nextInt(5)} |
| Encaixes | ${rnd.nextInt(4)} |

## O que aconteceu

- ${_paragrafo(rnd)} ${links(1)}
- ${_paragrafo(rnd)}

${faltas > 5 ? '> [!risco] Faltas acima do esperado\n> ${_paragrafo(rnd)} ${links(1)}\n' : ''}
## Entidades citadas

${entidades(2 + rnd.nextInt(3))}

#diario
''',
      ));
    }

    // ── 4 · Imperfeições propositais ────────────────────────────────────────

    // Órfãs (~3%): nenhuma entrada, nenhuma saída.
    final nOrfas = (alvo * 0.03).round();
    for (var i = 0; i < nOrfas; i++) {
      final t = 'Rascunho solto ${i + 1}';
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: _Ref(proximoId(), t, 'inbox/${_slug(t)}.md'),
        tipo: NotaTipo.nota,
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(90))),
        conteudo: '# $t\n\n${_paragrafo(rnd)}\n',
      ));
    }

    // Links quebrados (~2%): apontam para notas que não existem.
    final nQuebrados = (alvo * 0.02).round();
    for (var i = 0; i < nQuebrados; i++) {
      final t = 'Ideia pendente ${i + 1}';
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: _Ref(proximoId(), t, 'inbox/${_slug(t)}.md'),
        tipo: NotaTipo.nota,
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(60))),
        conteudo: '# $t\n\n${_paragrafo(rnd)}\n\n'
            'Depende de [[Protocolo que ainda não escrevemos $i]] '
            'e de [[Estudo inexistente $i]].\n',
      ));
    }

    // Notas sensíveis (~1%).
    final nSensiveis = (alvo * 0.01).round();
    for (var i = 0; i < nSensiveis; i++) {
      final t = 'Ocorrência restrita ${i + 1}';
      notas.add(_montar(
        clinicaId: clinicaId,
        ref: _Ref(proximoId(), t, 'restrito/${_slug(t)}.md'),
        tipo: NotaTipo.nota,
        sensivel: true,
        criadaEm: hoje.subtract(Duration(days: rnd.nextInt(120))),
        conteudo: '---\ntipo: nota\nsensivel: true\n---\n\n# $t\n\n'
            '> [!lgpd] Acesso restrito\n> ${_paragrafo(rnd)}\n\n'
            'Envolvidos: ${entidades(2)}\n\nRelacionado: ${links(1)}\n',
      ));
    }

    return notas;
  }

  // ── Infra do gerador ──────────────────────────────────────────────────────

  static List<_Ref> _serie(
    int n,
    String Function() proximoId,
    (String, String) Function(int) fabrica,
  ) {
    final out = <_Ref>[];
    final usados = <String>{};
    for (var i = 0; i < n; i++) {
      final (titulo, path) = fabrica(i);
      // Títulos precisam ser únicos, senão a resolução vira ambígua de propósito.
      final tituloFinal = usados.add(titulo) ? titulo : '$titulo ${i + 1}';
      out.add(_Ref(proximoId(), tituloFinal, path));
    }
    return out;
  }

  static Nota _montar({
    required String clinicaId,
    required _Ref ref,
    required String conteudo,
    required NotaTipo tipo,
    required DateTime criadaEm,
    NotaOrigem origem = NotaOrigem.humano,
    NotaEstado estado = NotaEstado.publicada,
    double? confianca,
    String? revisadoPor,
    bool fixada = false,
    bool sensivel = false,
  }) =>
      Nota(
        id: ref.id,
        clinicaId: clinicaId,
        path: ref.path,
        titulo: ref.titulo,
        tipo: tipo,
        conteudo: conteudo.trimLeft(),
        origem: origem,
        estado: estado,
        confianca: confianca,
        revisadoPor: revisadoPor,
        fixada: fixada,
        sensivel: sensivel,
        createdAt: criadaEm,
        updatedAt: criadaEm.add(Duration(hours: 1 + criadaEm.day % 12)),
        createdBy: origem == NotaOrigem.agente ? 'agt_cerebro' : 'usr_demo',
        updatedBy: origem == NotaOrigem.agente ? 'agt_cerebro' : 'usr_demo',
      );

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _slug(String s) {
    const com = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const sem = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final ch = String.fromCharCode(r);
      final i = com.indexOf(ch);
      b.write(i >= 0 ? sem[i] : ch);
    }
    return b
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }

  static T _pick<T>(List<T> lista, math.Random rnd) =>
      lista[rnd.nextInt(lista.length)];

  static String _paragrafo(math.Random rnd) {
    final n = 2 + rnd.nextInt(3);
    return List.generate(n, (_) => _pick(_frases, rnd)).join(' ');
  }

  // ── Vocabulário ───────────────────────────────────────────────────────────

  static const _mocs = <(String, String)>[
    ('Operação Clínica — MOC', 'operacao'),
    ('Absenteísmo — MOC', 'absenteismo'),
    ('Equipe Médica — MOC', 'equipe'),
    ('Pacientes e Risco — MOC', 'pacientes'),
    ('Agenda e Capacidade — MOC', 'agenda'),
    ('Satisfação e Reputação — MOC', 'satisfacao'),
  ];

  static const _temas = [
    'Absenteísmo', 'Overbooking', 'Fila de espera', 'Confirmação',
    'Telemedicina', 'Recepção', 'Triagem', 'Encaixe', 'Cancelamento',
    'Capacidade de agenda', 'Tempo de espera', 'Retorno de paciente',
    'Reputação', 'Satisfação', 'Health score', 'Risco de falta',
    'Distribuição de horários', 'Ocupação de salas', 'Lembrete automático',
  ];

  static const _qualificadores = [
    'por turno', 'por profissional', 'na primeira consulta', 'em retorno',
    'no SUS', 'em convênio', 'na alta demanda', 'fora de pico',
    'em telemedicina', 'no presencial',
  ];

  static const _recortes = [
    '— visão semanal', '— corte por turno', '— por especialidade',
    '— janela de 90 dias', '— comparativo trimestral', '— recorte por unidade',
    '— coorte de primeira consulta',
  ];

  static const _processos = [
    'Confirmação', 'Reagendamento', 'Encaixe', 'Triagem', 'Acolhimento',
    'Alta', 'Chamada de fila', 'Contato ativo', 'Registro de falta',
  ];

  static const _escopos = [
    '48h', '24h', 'em D-1', 'no mesmo dia', 'para telemedicina',
    'na recepção', 'no totem', 'via WhatsApp', 'por telefone',
  ];

  static const _padroesTexto = [
    'Faltas de segunda de manhã', 'Queda de confirmação no fim do mês',
    'Encaixe eficaz em slot crítico', 'Retorno não agendado na alta',
    'Fila que estoura após as 16h', 'Cancelamento tardio em convênio',
    'Primeira consulta com risco maior', 'Chuva e aumento de falta',
    'Agenda desbalanceada entre profissionais', 'Slot de 7h com baixa adesão',
  ];

  static const _decisoesTexto = [
    'Adotar confirmação em duas ondas', 'Limitar encaixe a um por hora',
    'Priorizar fila por tempo de espera', 'Reduzir slots de 7h',
    'Ativar lembrete por WhatsApp', 'Padronizar registro de falta',
    'Revisar limiar de overbooking',
  ];

  static const _fontesTexto = [
    'Diretriz de acesso ambulatorial', 'Estudo sobre no-show ambulatorial',
    'Manual de regulação assistencial', 'Nota técnica de teleatendimento',
    'Guia de indicadores de acesso', 'Revisão sobre adesão a lembretes',
  ];

  static const _papeis = [
    'Recepção', 'Coordenação', 'Enfermagem', 'Regulação', 'Gestão',
  ];

  static const _indicadores = [
    'Taxa de falta', 'Taxa de confirmação', 'Ocupação', 'Tempo médio de espera',
    'Encaixes aproveitados', 'Cancelamento tardio', 'Satisfação',
  ];

  static const _tags = [
    'operacao', 'operacao/absenteismo', 'operacao/agenda', 'operacao/fila',
    'clinica', 'clinica/qualidade', 'analise', 'analise/tendencia',
    'protocolo', 'decisao', 'q1', 'q2', 'q3', 'q4', 'prioridade',
    'equipe', 'paciente', 'telemedicina', 'sus', 'convenio',
  ];

  static const _frases = [
    'O efeito aparece com mais força nos turnos de início da manhã.',
    'A correlação é consistente, mas o tamanho da amostra ainda é pequeno.',
    'O comportamento muda quando a confirmação chega dentro da janela útil.',
    'Há dependência clara do intervalo entre marcação e atendimento.',
    'O desvio se concentra em poucos profissionais, não na agenda inteira.',
    'A recepção relata que o gargalo aparece depois do meio da tarde.',
    'Os dados de convênio e SUS se comportam de forma diferente aqui.',
    'A hipótese explica parte do fenômeno, mas não o pico observado.',
    'A medida reduziu o indicador sem aumentar o tempo de espera.',
    'Vale reavaliar depois de um trimestre completo de dados.',
    'O registro manual introduz ruído que precisa ser considerado.',
    'A fila absorveu a variação sem impacto perceptível no atendimento.',
  ];
}

class _Ref {
  const _Ref(this.id, this.titulo, this.path);
  final String id;
  final String titulo;
  final String path;
}
