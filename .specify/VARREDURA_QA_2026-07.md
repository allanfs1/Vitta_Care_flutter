# 🔍 Varredura de QA — Bugs, Correções, Testes e Roadmap (2026-07-06)

> Auditoria focada na **lógica pura e de domínio** (onde bugs reais vivem e onde
> testes automatizados conseguem validar de fato). Priorizou arquivos **não
> modificados** no working tree para as correções poderem ser integradas sem
> sobrescrever trabalho em andamento. Escopo consciente: não é uma auditoria
> exaustiva de toda a UI — é um corte vertical de alto valor + suíte de testes.

---

## 1. Bugs encontrados e corrigidos

| # | Severidade | Arquivo | Problema | Correção |
|---|-----------|---------|----------|----------|
| B1 | **Média** (dados) | `lib/core/widgets/charts.dart` — `LegendPieChart` | `data[i].value / total` sem guardar `total == 0` (dados vazios/zerados) → título do gráfico exibia **`NaN%`**. | Título passa a mostrar `0%` quando `total <= 0`. |
| B2 | **Baixa** (robustez) | `lib/core/widgets/charts.dart` — `SimpleBarChart` | `maxY = (max * 1.25)` vira **0** com dados vazios → escala inválida no fl_chart (risco de assert/gráfico quebrado). | `topY` cai para `1.0` quando não há valor positivo. |
| B3 | **Baixa** (robustez) | `lib/core/widgets/charts.dart` — `DonutChart` | `100 - percent` fica **negativo** quando `percent > 100` (acontece na ocupação de overbooking) → seção de pizza inválida. | Desenho usa `percent.clamp(0,100)`; o rótulo central segue mostrando o valor real. |
| B4 | **Média** (estado) | `lib/features/absenteismo/absenteismo_screen.dart` | `ref.watch(patientsProvider)..sort(...)` ordenava **in-place** a lista compartilhada (`MockData.patients`) durante o `build` — efeito colateral que reordenava a fonte global vista por outras telas (ex.: Pacientes). | Copia antes de ordenar: `[...ref.watch(patientsProvider)]..sort(...)`. |
| B5 | **Média** (métrica latente) | `lib/core/models/enums.dart` — `AppointmentStatus.fromString` | Reconhecia `falta`/`no_show` mas **não** `faltou` — exatamente o rótulo que `FirestoreAppointmentService._statusLabel(noShow)` grava em `tb_agendamentos`. Também ignorava `reagendado`/`pre-agendado`/`pendente`. Strings reais caíam no default `pending`, distorcendo métricas de absenteísmo. | Superset de rótulos + `trim()`, alinhado ao parser do serviço/Cloud Functions. |

### Verificação
- `flutter analyze` nos 4 arquivos alterados → **No issues found**.
- Suíte de testes de lógica pura (novo `test/core/core_logic_test.dart`) → **17/17 verdes**, cobrindo B5, B1..B3 (indiretamente via faixas) e regressões de domínio.

---

## 2. Testes automatizados adicionados

| Arquivo | Cobertura |
|---------|-----------|
| `test/core/core_logic_test.dart` (17 testes) | `AppointmentStatus.fromString` (incl. `faltou`, normalização, default); `OccupancyLevel.from` (limiares e normalização de capacidade ≤ 0); `Doctor.capacityAt` (precedência período>dia>global, teto rígido, nunca zera); `HealthClassification.fromScore`; `PatientHealthScore.initials`; `Plan.yearlyDiscountPercent` + `Plan.fromFirestore`; `Validators` (cpf/email/senha/cep/cnpj). |
| `test/features/overbooking_engine_test.dart` (4 testes) | Motor de overbooking: detecção de estouro, escolha do paciente mais tolerável, sugestão de novo horário futuro, exclusão de realizados/faltantes. |

> **Observação (atualizada):** as **12 falhas** observadas eram exclusivas do
> `origin/main` (base do worktree) — no working tree atual (`master`) a suíte
> completa passa: **117 testes verdes, 0 falhas**. Ou seja, o `StateError` do
> `new_appointment_dialog` **já está resolvido** no WIP local (R5 não se aplica).

---

## 3. Recursos/melhorias sugeridos (não implementados — priorizados)

| ID | Prioridade | Descrição |
|----|-----------|-----------|
| R1 | ✅ **Feito** | **`firstWhere` sem `orElse`** em `totem_profiles_provider.dart` (`configFor`) e `totem_config_panel.dart` (`_profileLabel`, `restore`): `kTotemProfiles.firstWhere((p) => p.id == id)` lançava `StateError` se o id não existisse (override remoto/persistido de perfil removido). Corrigido com `orElse`/busca segura, aplicado ao `master` (analyze limpo, suíte verde). |
| R2 | ✅ **Feito** | **Persistência da realocação no servidor**: nova camada `RealocacaoService` (Mock offline + `FirestoreRealocacaoService`) espelha cada proposta em `queue_realoc`, registra decisões em `tb_overbooking_events` e permite **delegar ao servidor** enfileirando uma Tarefa Agendada em `tb_scheduled_tasks` (executada pelo `scheduledTasksCron` com o app fechado). Notifier ligado best-effort (no-op offline); override Firestore em `main.dart`; botão "Delegar ao servidor" no card. Mapeamentos (`realocQueueDoc`/`overbookingEventDoc`/`scheduledTaskDoc`) são puros e testados. *(As Cloud Functions dedicadas `detectOverbookingSurplus`/`runRealocacaoEngine`/`sendRealocacaoEmail` seguem como passo futuro — hoje o cron genérico executa a tarefa enfileirada.)* |
| R3 | ✅ **Feito** | **Central de Notificações**: já existia (feed, tipos, marcar lida/todas, filtro, badge de não lidas no `AppHeader`). Enriquecida para refletir **eventos reais**: novos `add`/`push` no notifier + tipo `overbooking`; as realocações (envio do e-mail e conclusão) passam a emitir notificação in-app (conecta R2↔R3). Testado (`notificacoes_provider_test.dart`). |
| R4 | ✅ **Feito** | **Estados assíncronos padronizados**: `core/widgets/async_states.dart` (`LoadingView`/`EmptyView`/`ErrorView`/`SkeletonBox`) já existia e é usado em ~10 telas. Padronizei os estados vazios ad-hoc da feature de **overbooking** (4 abas) para `EmptyView`. Testes de widget cobrindo os 3 componentes (`test/core/async_states_test.dart`). *(Aplicar a mesma padronização às demais telas com `Center(Text(...))` avulso é o passo incremental restante.)* |
| R5 | ✅ N/A | **Falhas de teste** — verificadas: as 12 falhas eram só do `origin/main`; no `master` a suíte passa (117 verdes). Sem ação necessária. |
| R6 | ✅ **Feito** | **Consistência de status**: extraído o mapeamento canônico para `AppointmentStatus.apiLabel` (inverso de `fromString`) em `core/models/enums.dart`. `FirestoreAppointmentService` passou a delegar leitura (`fromString`) e escrita (`apiLabel`), removendo o `_status` duplicado. Teste de round-trip cobre os 5 status. *(As MCP tools em Node seguem com o próprio mapa; alinhá-las é o passo restante.)* |
| R7 | 🟢 Baixa | **i18n real (ARB)** — hoje só há troca de locale sem traduções (lacuna registrada no AGENTS.md). |
| R8 | 🟢 Baixa | **Testes de widget/integração** para os fluxos críticos (criar agendamento, realocação, recepção) além dos testes de unidade. |

---

## 4. Arquivos afetados nesta entrega

| Ação | Arquivo |
|------|---------|
| Editar | `lib/core/widgets/charts.dart` (B1, B2, B3) |
| Editar | `lib/core/models/enums.dart` (B5) |
| Editar | `lib/features/absenteismo/absenteismo_screen.dart` (B4) |
| Criar | `test/core/core_logic_test.dart` |
| Criar | `.specify/VARREDURA_QA_2026-07.md` (este arquivo) |

> A feature de Overbooking (arquivos `lib/features/overbooking/*` + `test/features/overbooking_engine_test.dart`) foi entregue na iteração anterior e está documentada no `.specify/AGENTS.md`.
