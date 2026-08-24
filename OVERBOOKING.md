# Overbooking — Especificação de Correções e Melhorias

> **Objetivo:** documentar o estado atual do overbooking no sistema, os **bugs**
> encontrados e **todas as modificações** que serão feitas (correções +
> implementações de melhoria), incluindo uma **nova página dedicada** de gestão
> de overbooking.
> **Data:** 02/07/2026 · **Escopo aprovado:** as 4 superfícies + spec e implementação.

---

## 1. Arquitetura atual

O overbooking ("overbooking inteligente §1") é modelado no `Doctor` e consumido
em quatro superfícies. Não existia, até esta entrega, uma **página** única de
gestão de overbooking.

### 1.1 Modelo — `lib/core/models/doctor.dart`
Campos relevantes:
| Campo | Origem Firestore | Significado |
|-------|------------------|-------------|
| `slotLimit` | `limiteSlot` | Limite base de pacientes por horário |
| `maxOverbook` | `limitesSeguranca.maxOverbook` | Overbook global permitido |
| `maxPerSlot` | `limitesSeguranca.maxPacientesPorHorario` | Teto rígido por horário |
| `dayOverbook` | `overbookingConfig` | Overbook por dia da semana (1..7) |
| `periodOverbook` | `overbookingPeriodo` | Overbook por período (manha/tarde/noite) |

Cálculo de capacidade: `int capacityAt(int weekday, String hhmm)`.

### 1.2 Superfícies que consomem
| # | Superfície | Arquivo | Papel |
|---|-----------|---------|-------|
| S1 | Totem (paciente) | `lib/features/totem/totem_screen.dart` | Indicador de ocupação (LIVRE/MÉDIA/ÚLTIMAS/LOTADO) por slot |
| S2 | Agenda do médico | `lib/features/equipe_medica/medico_agenda_screen.dart` | Timeline em tempo real com `booked/capacity` e vagas |
| S3 | MCP / IA | `lib/core/modules/mcp/tools/overbooking_sus_tools.dart`, `pacientes_risco_tools.dart` | Painel, horários livres, simulação, lista de espera |
| S4 | Config do totem | `lib/features/totem/widgets/totem_config_panel.dart` | Liga/desliga o indicador (`showOccupancy`) |

---

## 2. Bugs encontrados

### B1 — `capacityAt`: `min(dia, período)` anula o overbook por período *(severidade: média)*
`capacityAt` faz `overbook = min(dayOver, periodOver)`, e ambos usam
`?? maxOverbook` como padrão. Consequência: um override de período (ex.: médico
`d3` tem `periodOverbook: {'manha': 3}`, `maxOverbook: 1`) **nunca é aplicado**,
porque `min(1, 3) = 1`. A configuração de período vira "config morta".
- **Esperado:** o valor **mais específico** deve prevalecer — período > dia > global.
- **Correção:** resolver por precedência (não por `min`), respeitando `0` explícito.

### B2 — `capacityAt`: `maxPerSlot = 0` zera a capacidade *(severidade: média)*
`if (cap != null && total > cap) total = cap;` — se `maxPerSlot` for `0`, a
capacidade final vira `0`, e todo slot fica **"LOTADO"** mesmo vazio. Um teto de
`0`/negativo deveria significar "sem teto".
- **Correção:** aplicar o teto apenas quando `cap > 0`; garantir `total >= 1`.

### B3 — `_Slot.ratio`/`full` no totem tratam `capacity <= 0` como cheio *(severidade: baixa)*
`double get ratio => capacity <= 0 ? 1 : booked / capacity;` e
`bool get full => booked >= capacity;`. Com `capacity = 0`, `full` é `true` para
qualquer `booked` (inclusive 0). Depende de B2 para acontecer, mas deve ser
endurecido de forma defensiva no próprio slot.
- **Correção:** normalizar `capacity` para `>= 1` no cálculo de ocupação.

### B4 — Agenda do médico com janela fixa 7–18h *(severidade: média)*
`_startHour = 7; _endHour = 18` são constantes. Ignora o horário real de
funcionamento e **esconde** consultas fora dessa faixa (ex.: 06:00, 19:00, plantão).
- **Correção:** janela **adaptativa** — expande para cobrir a primeira/última
  consulta do dia (mantendo a faixa comercial como mínimo).

### B5 — Agenda do médico: fallback de capacidade some sem médico carregado *(severidade: baixa)*
`capacity = doctor?.capacityAt(...) ?? (booked > 0 ? booked : 1)`. Enquanto o
médico não carrega, a capacidade fica igual a `booked` → sempre "Lotado" e sem
vagas, mesmo que haja folga.
- **Correção:** fallback mínimo mais realista e rótulo "—/—" enquanto carrega.

### B6 — Thresholds de ocupação divergentes entre superfícies *(severidade: média — consistência)*
- Totem (`_occColor`): vermelho `≥ 0.8`, âmbar `≥ 0.5`, verde caso contrário.
- Agenda do médico (`_capColor`): vermelho `≥ 1.0`, âmbar `≥ 0.7`, verde caso contrário.
Dois lugares, duas regras, cores diferentes → leitura inconsistente do mesmo
conceito.
- **Correção/Melhoria:** extrair para um **modelo único** (`OccupancyLevel`).

### B7 — MCP `overbooking_horarios_livres` usa limite fixo `4` *(severidade: média)*
`const limitePorHora = 4;` ignora `limiteSlot`/overbook do médico → resultado
inconsistente com o app. Também usa janela fixa 7–18.
- **Correção:** calcular a capacidade a partir do documento do médico
  (`limiteSlot` + overbook), com fallback `4` só quando não houver config.

### B8 — Slots :30 invisíveis no totem *(severidade: baixa — documentado, não corrigido nesta entrega)*
`_buildSlots` gera apenas horários de hora cheia (`HH:00`); agendamentos em
`HH:30` são contados numa chave sem slot correspondente e não impactam a
capacidade exibida. Fica registrado como limitação conhecida.

---

## 3. Modificações planejadas

### M1 — `doctor.dart` · corrigir `capacityAt` (resolve B1, B2)
Nova regra de resolução do overbook:
```dart
int capacityAt(int weekday, String hhmm) {
  final period = hhmm.compareTo('12:00') < 0
      ? 'manha'
      : (hhmm.compareTo('18:00') < 0 ? 'tarde' : 'noite');
  // Precedência: período > dia > global.
  final overbook = periodOverbook[period] ?? dayOverbook[weekday] ?? maxOverbook;
  final base = slotLimit < 1 ? 1 : slotLimit;
  var total = base + (overbook < 0 ? 0 : overbook);
  final cap = maxPerSlot;
  if (cap != null && cap > 0 && total > cap) total = cap; // teto só quando > 0
  return total < 1 ? 1 : total;                            // nunca zera
}
```

### M2 — novo modelo compartilhado `OccupancyLevel` (resolve B6) — I1
Arquivo novo: `lib/features/overbooking/occupancy.dart`.
- Enum `OccupancyLevel { livre, media, ultimas, lotado }`.
- `factory OccupancyLevel.from({required int booked, required int capacity})`
  com thresholds únicos: `lotado` quando `booked >= capacity`; `ultimas` quando
  `ratio >= 0.8`; `media` quando `ratio >= 0.5`; senão `livre`.
- `color`, `label` e `ratio` centralizados.
- Consumido por totem (S1), agenda do médico (S2) e nova página (S5).

### M3 — Totem usa o modelo compartilhado (resolve B3) — S1
- `_Slot.ratio`/`full` normalizam `capacity` para `>= 1`.
- `_occColor`/`_occBadge`/`_occLegend` passam a derivar de `OccupancyLevel`.
- Comportamento visual preservado (mesmas 4 cores/labels), agora consistente.

### M4 — Agenda do médico (resolve B4, B5) — S2
- Janela adaptativa: `min(7, primeiraConsulta)` … `max(18, últimaConsulta+1)`.
- Fallback de capacidade e estado "carregando" mais claros.
- `_capColor` derivado de `OccupancyLevel` (alinha com o totem).

### M5 — **Nova página dedicada** `OverbookingScreen` (`/overbooking`) — S5 · I2
Painel de **gestão de overbooking da clínica** (autenticado, dentro do shell):
- Seletor de data (◀ hoje ▶).
- Cabeçalho com KPIs do dia: total agendado, capacidade total, taxa de ocupação,
  nº de slots lotados.
- Para cada médico ativo da clínica: linha com ocupação por hora
  (`booked/capacity`, vagas, chip de `OccupancyLevel`), reaproveitando
  `capacityAt` e `appointmentsProvider`.
- **Editor de configuração** por médico (diálogo): `slotLimit`, `maxOverbook`,
  `maxPerSlot`, persistido via `clinicDoctorsProvider.notifier.update(...)`.
- Registro: `AppRoutes.overbooking` no router (dentro do `ShellRoute`), item em
  `nav_destinations.dart` (secundário) e módulo em `module_registry.dart`
  (`id: 'overbooking'`, depende de `equipe_medica`).

### M6 — MCP `overbooking_horarios_livres` (resolve B7) — S3
- Ler o documento do médico (`tb_medicos/{id}`) e computar
  `capacidade = limiteSlot + overbook` (período > dia > global), com teto
  `maxPacientesPorHorario` e fallback `4` quando não houver config.
- `livres = (capacidade - ocupacao)` por hora.

---

## 4. Arquivos afetados

| Ação | Arquivo |
|------|---------|
| Editar | `lib/core/models/doctor.dart` (M1) |
| Criar | `lib/features/overbooking/occupancy.dart` (M2) |
| Criar | `lib/features/overbooking/overbooking_screen.dart` (M5) |
| Editar | `lib/features/totem/totem_screen.dart` (M3) |
| Editar | `lib/features/equipe_medica/medico_agenda_screen.dart` (M4) |
| Editar | `lib/navigation/app_router.dart` (M5 — rota) |
| Editar | `lib/navigation/nav_destinations.dart` (M5 — item de menu) |
| Editar | `lib/core/modules/module_registry.dart` (M5 — módulo) |
| Editar | `lib/core/modules/mcp/tools/overbooking_sus_tools.dart` (M6) |

---

## 5. Testes / validação
- `flutter analyze` nos arquivos alterados (sem novos erros/avisos).
- Verificação manual no navegador: página `/overbooking` renderiza ocupação por
  médico; edição de config reflete na capacidade; totem e agenda do médico
  mantêm o comportamento visual, agora com thresholds unificados.
- Casos de regressão de `capacityAt` (ver §6).

## 6. Casos de regressão de `capacityAt` (dados de mock)
| Médico | Slot | Antes | Depois | Observação |
|--------|------|:-----:|:------:|-----------|
| d1 (slotLimit 1, over 2, cap 3) | 09:00 | 3 | 3 | inalterado |
| d3 (slotLimit 2, over 1, manhã 3, cap 5) | 09:00 (manhã) | 3 | **5** | B1 corrigido: período (3) aplicado → 2+3=5 |
| d3 | 15:00 (tarde) | 3 | 3 | tarde usa dia/global (1) → 2+1=3 |
| qualquer com `maxPerSlot=0` | — | 0 (LOTADO) | ≥1 | B2 corrigido |

## 7.1 Status da implementação (02/07/2026)
Todas as modificações M1–M6 foram **implementadas** e o `flutter analyze` dos
arquivos alterados terminou com **"No issues found"**. Verificação visual da
página `/overbooking` no navegador depende de um rebuild do servidor de dev e de
login autenticado (Firebase) — pendente de execução pelo dono do ambiente.

| Mod | Descrição | Status |
|-----|-----------|:------:|
| M1 | `capacityAt` precedência período>dia>global + teto/`>=1` | ✅ |
| M2 | `OccupancyLevel` compartilhado | ✅ |
| M3 | Totem usa `OccupancyLevel` + guarda de capacidade | ✅ |
| M4 | Agenda do médico: janela adaptativa + fallback + cores unificadas | ✅ |
| M5 | Página `/overbooking` + rota + nav + módulo | ✅ |
| M6 | MCP `overbooking_horarios_livres` com capacidade real | ✅ |

## 7. Fora de escopo (registrado)
- B8 (slots `:30` no totem) — exige redesenho da grade de horários.
- M6 avançado (painel MCP com slots reais) — mantém estimativa atual.
- Escrita de `dayOverbook`/`periodOverbook` pela UI — o editor cobre
  `slotLimit`/`maxOverbook`/`maxPerSlot`; os mapas por dia/período seguem
  editáveis apenas via dados/Firestore nesta entrega.
