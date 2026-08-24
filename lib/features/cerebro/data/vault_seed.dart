import 'models/nota.dart';
import 'models/nota_enums.dart';

/// Vault semente (`obsidian.md` §20.1) — as 8 notas criadas no onboarding
/// ("Deixar a IA semear").
///
/// Elas já nascem interligadas: o vault começa com densidade de conexão
/// próxima de 3,0, nunca como um punhado de pontos soltos (mitigação do
/// risco R4 — "cérebro vira depósito").
class VaultSeed {
  VaultSeed._();

  static List<Nota> gerar(String clinicaId, {DateTime? agora}) {
    final ts = agora ?? DateTime.now();
    final hoje = _iso(ts);

    final fontes = <_Semente>[
      _Semente(
        path: '000-inicio.md',
        tipo: NotaTipo.moc,
        fixada: true,
        conteudo: '''
---
aliases: [Início, Home, Porta de entrada]
tipo: moc
tags: [moc, inicio]
---

# 000 · Início

Porta de entrada do Cérebro da clínica. Tudo que importa começa aqui.

> [!insight] Como usar
> Escreva ligando. Uma nota sem `[[links]]` é uma nota que o Cérebro não
> consegue lembrar depois. Ao citar gente ou consulta, use `[[@medico:id]]` —
> nunca copie nome de paciente para dentro do texto.

## Mapas

- [[mocs/operacao|Operação]] — agenda, recepção, fila
- [[mocs/absenteismo|Absenteísmo]] — faltas e cancelamentos
- [[mocs/equipe|Equipe]] — quem faz o quê
- [[mocs/pacientes|Pacientes]] — risco e acompanhamento

## Normas vigentes

- [[protocolos/confirmacao-48h]]
- [[protocolos/overbooking]]

## Hoje

- [[diario/$hoje]]
''',
      ),
      _Semente(
        path: 'mocs/operacao.md',
        tipo: NotaTipo.moc,
        conteudo: '''
---
aliases: [Operação, Operação Clínica]
tipo: moc
tags: [moc, operacao]
---

# Operação Clínica — MOC

Como a clínica funciona no dia a dia. Sobe de [[000-inicio]].

## Fluxo do paciente

Chegada → recepção → fila → atendimento → desfecho. Cada etapa tem um ponto
onde a operação costuma quebrar; os pontos conhecidos estão abaixo.

## Pontos de atrito conhecidos

- Confirmação não disparada no turno da manhã → [[mocs/absenteismo]]
- Encaixe sem critério claro → [[protocolos/overbooking]]
- Agenda desbalanceada entre profissionais → [[mocs/equipe]]

## Normas

- [[protocolos/confirmacao-48h]]
- [[protocolos/overbooking]]

#operacao
''',
      ),
      _Semente(
        path: 'mocs/absenteismo.md',
        tipo: NotaTipo.moc,
        fixada: true,
        conteudo: '''
---
aliases: [Absenteísmo, Faltas, No-show]
tipo: moc
tags: [moc, operacao/absenteismo]
status: vivo
---

# Absenteísmo — MOC

links: [[mocs/operacao|Operação]] · [[000-inicio|Início]] · [[@clinica:$clinicaId]]

> [!risco] O que sabemos até agora
> Faltas não são aleatórias: elas se concentram em turnos, dias e perfis.
> Toda hipótese registrada aqui precisa apontar para a evidência que a sustenta. ^hipotese-base

## Diagnóstico

- Turnos de início de manhã concentram falta acima do esperado
- Intervalo longo entre marcação e consulta aumenta o risco
- Confirmação não recebida é o maior preditor isolado → [[protocolos/confirmacao-48h]]

## Ações em curso

- [x] Definir protocolo de confirmação → [[protocolos/confirmacao-48h]]
- [ ] Medir efeito do overbooking controlado → [[protocolos/overbooking]]
- [ ] Revisar distribuição de agenda por profissional → [[mocs/equipe]]

## Onde olhar

- Pacientes de maior risco: [[mocs/pacientes]]
- Registro diário: [[diario/$hoje]]

#operacao/absenteismo #moc
''',
      ),
      _Semente(
        path: 'mocs/equipe.md',
        tipo: NotaTipo.moc,
        conteudo: '''
---
aliases: [Equipe, Equipe Médica, Corpo clínico]
tipo: moc
tags: [moc, equipe]
---

# Equipe — MOC

Sobe de [[000-inicio]]. Relaciona-se com [[mocs/operacao]].

## Como usamos esta nota

Cada profissional entra aqui como referência de entidade — o Cérebro resolve
o nome na interface para quem tem permissão de ver.

## Leitura cruzada

- Distribuição de faltas por profissional: [[mocs/absenteismo]]
- Critério de encaixe por agenda: [[protocolos/overbooking]]

#equipe
''',
      ),
      _Semente(
        path: 'mocs/pacientes.md',
        tipo: NotaTipo.moc,
        conteudo: '''
---
aliases: [Pacientes, Risco de paciente]
tipo: moc
tags: [moc, pacientes]
---

# Pacientes — MOC

> [!lgpd] Regra inegociável
> Nome, CPF, telefone e e-mail **não** entram no corpo das notas. Use sempre
> `[[@paciente:id]]`. A interface resolve a identidade só para quem pode vê-la.

## Acompanhamento por risco

O score de risco vem do módulo de absenteísmo e é reavaliado de madrugada.
Ele explica *quem* tende a faltar; [[mocs/absenteismo]] explica *por quê*.

## Ligações

- [[protocolos/confirmacao-48h]] — o que disparamos e quando
- [[mocs/operacao]] — onde o paciente encosta no processo

#pacientes
''',
      ),
      _Semente(
        path: 'protocolos/confirmacao-48h.md',
        tipo: NotaTipo.protocolo,
        conteudo: '''
---
aliases: [Protocolo de Confirmação 48h, Confirmação 48h]
tipo: protocolo
tags: [protocolo, operacao/absenteismo]
status: vigente
---

# Protocolo de Confirmação 48h

Norma vigente da clínica. Alterações aqui só por decisão humana registrada.

## Regra

1. 48 h antes: mensagem de confirmação com opção de remarcar
2. 24 h antes: lembrete para quem não respondeu
3. Sem resposta após o lembrete: sinaliza para a recepção ligar

## Por que existe

Ausência de confirmação é o preditor mais forte de falta que conhecemos —
ver [[mocs/absenteismo]].

## Quando falha

- Integração de mensagens fora do ar no horário de disparo
- Contato desatualizado no cadastro
- Disparo fora da janela útil (madrugada)

Relacionado: [[protocolos/overbooking]] · [[mocs/operacao]]

#protocolo
''',
      ),
      _Semente(
        path: 'protocolos/overbooking.md',
        tipo: NotaTipo.protocolo,
        conteudo: '''
---
aliases: [Protocolo de Overbooking, Encaixe]
tipo: protocolo
tags: [protocolo, operacao]
status: vigente
---

# Protocolo de Overbooking

Encaixe controlado a partir da fila de espera, apenas em slots de risco alto.

## Regra

1. Só entra em slot com risco de falta acima do limiar definido
2. No máximo um encaixe por hora por profissional
3. Encaixe é oferecido a quem está na fila há mais tempo, respeitando prioridade
4. Toda realocação vira registro — nada de encaixe informal

## Risco de aplicar errado

Encaixe em slot de risco baixo gera sala cheia e espera — o remédio vira
sintoma. Ver [[mocs/absenteismo]] antes de mexer no limiar.

Relacionado: [[protocolos/confirmacao-48h]] · [[mocs/operacao]] · [[mocs/equipe]]

#protocolo
''',
      ),
      _Semente(
        path: 'diario/$hoje.md',
        tipo: NotaTipo.diario,
        origem: NotaOrigem.sistema,
        conteudo: '''
---
tipo: diario
data: $hoje
tags: [diario, operacao]
---

# $hoje

← anterior · [[000-inicio|Início]] · [[mocs/operacao|Operação]]

## Números do dia

A consolidação noturna preenche esta seção com dados reais da agenda.

## O que aconteceu

- Cérebro inicializado com o vault semente.

## Perguntas em aberto

- Qual turno concentra as faltas nesta clínica? → [[mocs/absenteismo]]
- O protocolo de confirmação está sendo disparado na janela certa?
  → [[protocolos/confirmacao-48h]]
''',
      ),
    ];

    return [
      for (var i = 0; i < fontes.length; i++)
        _montar(fontes[i], clinicaId, ts, i),
    ];
  }

  static Nota _montar(_Semente s, String clinicaId, DateTime ts, int i) {
    final id = 'nt_seed_${i.toString().padLeft(2, '0')}';
    return Nota(
      id: id,
      clinicaId: clinicaId,
      path: s.path,
      titulo: '',
      tipo: s.tipo,
      conteudo: s.conteudo.trimLeft(),
      origem: s.origem,
      fixada: s.fixada,
      createdAt: ts,
      updatedAt: ts,
      createdBy: 'sistema',
      updatedBy: 'sistema',
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _Semente {
  const _Semente({
    required this.path,
    required this.conteudo,
    required this.tipo,
    this.origem = NotaOrigem.sistema,
    this.fixada = false,
  });

  final String path;
  final String conteudo;
  final NotaTipo tipo;
  final NotaOrigem origem;
  final bool fixada;
}
