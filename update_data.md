# 🗃️ update_data.md — Registro de Modificações

> Documenta alterações de dados/estrutura e o **porquê**, conforme exigido no
> `.specify/AGENTS.md` (seções "Escolher plano" e regras de trabalho).

---

## 2026-07-02 — /totem: implementação das 4 sugestões da verificação geral

### O que mudou
As sugestões registradas na auditoria do mesmo dia saíram do papel
(`flutter analyze` → 0 issues no módulo; sem erros no projeto):

1. **Teclado de CPF unificado** (`totem_screen.dart`): as duas implementações
   duplicadas (Wrap do Remarcar × GridView do Confirmar) viraram um único
   widget `_CpfKeypad` (grade 3×4, dígitos desabilitados aos 11, ⌫/LIMPAR
   desabilitados quando vazio, cor de destaque). Removidos `_keypadButton`,
   `_onKeypadPress`, `_formatCpfSearch`, `_numpad`, `_numKey` e `_cpfKey`.
2. **Slots na granularidade da consulta** (`_buildSlots` + prévia): a grade de
   horários agora avança no passo de `appointmentDuration` (ex.: 08:00, 08:30…
   com 30 min) em vez de fixa de hora em hora — o slot só entra se a consulta
   couber antes do fechamento. A ocupação ancora cada agendamento no slot da
   grade que o contém (consulta às 09:15 ocupa o slot 09:00 — antes, horários
   fora de HH:00 não contavam em slot nenhum). O filtro de "horários passados
   hoje" passou a comparar por minuto. A prévia usa a mesma regra (mostra os
   12 primeiros como amostra).
3. **Config sincronizada via Firestore** (`totem_config_provider.dart` e
   `totem_profiles_provider.dart`): com Firebase ativo, config e overrides de
   perfil espelham no doc `tb_totem_config/{clinicaId}` (campos `config` e
   `profiles`, escrita com `mergeFields` + `updatedAt`) e chegam **ao vivo**
   nos demais dispositivos via snapshot. SharedPreferences continua como
   cache/fallback (offline, mock ou regras bloqueando o totem público). Os
   providers agora observam `firebaseEnabledProvider` e
   `selectedClinicIdProvider` (config por clínica).
4. **Impressão real do comprovante** (`_printReceipt`): gera PDF em formato
   bobina 80 mm (`pdf` + novo pacote `printing`) com senha, paciente, médico,
   especialidade, data, antecedência e rodapé, e abre o diálogo de impressão
   do sistema/navegador. Falha vira aviso amigável. Dependência adicionada:
   `printing` (pubspec).

### Por quê
- Pedido: implementar as sugestões da verificação geral do totem.

### Notas / pendências
- A sincronização exige regras do Firestore permitindo leitura (e escrita para
  o painel) em `tb_totem_config/{clinicaId}`; a rota `/totem` é pública, então
  o dispositivo do totem precisa de permissão de leitura (ou manter-se logado).
- No Flutter Web o `printing` usa o diálogo de impressão do navegador; para
  impressora térmica dedicada, configurar a impressora padrão do quiosque.

---

## 2026-07-02 — /totem: verificação geral do sistema (bugs + melhorias)

### O que mudou
Auditoria completa do módulo Totem (fluxos Agendar/Remarcar, sessão, config,
perfis, prévia), corrigindo os achados pendentes do `totem_test.md` e bugs
novos encontrados na revisão. `flutter analyze lib/features/totem` → 0 issues.

**Bugs corrigidos:**
1. **F-1 — stale closure no painel de config** (`totem_config_panel.dart`):
   `_set` recebia a config capturada no closure do build; edições em sequência
   rápida revertiam o campo anterior. Agora `_set` recebe `TotemConfig
   Function(TotemConfig)` e muta o estado **atual** do provider (todos os ~40
   call sites atualizados; o stepper do almoço também passou a derivar o fim do
   estado atual).
2. **F-2 — cor de destaque parcial** (`totem_screen.dart`/`totem_preview.dart`):
   CTAs principais, títulos, tela de CPF, stepper (`_TotemStepper.accent`),
   tutorial (`_TotemTutorialModal.accent`), banner REMARCANDO, cartão do médico,
   slots, numpad e overlay de expiração agora seguem `accentColor`; gradientes
   derivam do accent (`Color.lerp` escurecido) em vez do vermelho fixo
   `0xFFFA4B53`. Com preset UBS (verde) o totem fica 100% coerente.
3. **Título de sucesso errado**: modo Remarcar sem consulta ativa cria uma
   consulta nova, mas a tela dizia "Consulta Remarcada!". Flag `_wasReschedule`
   (setada em `_doReschedule`/`_createAppointment`) corrige o título.
4. **Convidado no modo Remarcar duplicava**: `_submitNew` → `_createAppointment`
   ignorava `_reschedAppt` e criava outra consulta (que batia de novo no limite
   anti-abuso, em loop). Guard no `_createAppointment` redireciona para
   `_doReschedule` quando há remarcação em andamento.
5. **Ocupação inflada na remarcação**: `_buildSlots` contava a própria consulta
   sendo remarcada — o horário atual dela aparecia mais cheio/LOTADO. Excluída
   da contagem por `id`.
6. **Diálogos órfãos na expiração da sessão**: `_reset()` agora fecha qualquer
   `RawDialogRoute` aberto (tutorial, calendário, diálogo de limite) antes de
   voltar à tela inicial.
7. **UPA "24h" não era 24h**: preset fechava 23h (seg–sex) e **12h aos
   sábados**; agora `closeHour: 24` + `saturdayCloseHour: 24`. Os steppers do
   painel aceitam 0h–24h (antes 5h–23h, o que impedia até restaurar o preset).
8. **Timer da sessão** fazia 2 `setState` por segundo → unificado.

**Melhorias:**
- **Validação real de CPF** (dígitos verificadores) em Remarcar e Agendar —
  bloqueia CPFs impossíveis antes de consultar o Firestore. Atenção: testes
  manuais precisam de CPF válido (ex.: `529.982.247-25`, já no mock).
- **Validação de e-mail** no cadastro de convidado (typo silencioso deixava o
  paciente sem confirmação).
- **PIN de administrador** (`TotemConfig.adminPin`, seção SEGURANÇA): a rota
  `/totem` é pública e o painel abria com um simples toque longo no logo; com
  PIN definido, o acesso oculto pede o código (`_askPin`).

### Por quê
- Pedido: verificar todo o sistema do totem, corrigir bugs e aplicar melhorias.

### Sugestões futuras (não implementadas)
- Unificar os dois teclados de CPF duplicados (tela Remarcar × passo Confirmar).
- Slots com granularidade de `appointmentDuration` (hoje fixo de hora em hora;
  consultas fora de HH:00 não contam na ocupação do slot correspondente).
- Config do totem sincronizada via Firestore (hoje por dispositivo).
- Impressão real do comprovante (hoje simulada).

---

## 2026-06-26 — /totem: correção do "Abrir Calendário" + verificação do filtro

- **Abrir Calendário (bug)**: `showDatePicker` usava `firstDate: DateTime.now()`
  (hora atual) com `initialDate` em 00:00 do dia → violava `initialDate >= firstDate`
  e estourava ao abrir mais tarde no dia. Corrigido: `firstDate`/`initialDate`
  normalizados para início do dia (com clamp), `lastDate` +365d, tema na cor de
  destaque; a data escolhida vira o 1º dia da faixa semanal.
- **Filtro de especialidade**: verificado — funciona (chips derivados das
  especialidades dos médicos; `_buildSlots` filtra por `specialties.contains`).
  Chips/calendário/faixa de dias agora usam a **cor de destaque** da config.

---

## 2026-06-26 — /totem: sistema de configuração/personalização completo

### O que mudou
Novo sistema de configuração do totem, persistido em SharedPreferences:
- `models/totem_config.dart` — `TotemConfig` (marca/textos, cor de destaque,
  toggles de interface, fluxos, sessão e horários de funcionamento) + toJson/fromJson.
- `providers/totem_config_provider.dart` — `totemConfigProvider` (carrega/salva).
- `widgets/totem_config_panel.dart` — painel de ajustes em tela cheia (campos de
  texto, switches, sliders, steppers e seletor de cor), editando o provider.

**Acesso:** toque longo no cartão do nome da unidade (canto superior esquerdo)
abre o painel — oculto para pacientes.

**Aplicado na interface:** nome da unidade, título/subtítulo de boas-vindas, **cor
de destaque** (header, relógio, botões primários, ocupação), relógio on/off,
gradiente de fundo, **escala de fonte** (`textScaler`), cartão do médico on/off,
**indicador de ocupação/overbooking** on/off, botões Agendar/Remarcar habilitáveis,
botão de imprimir on/off.

**Aplicado no sistema:** tempo de inatividade, aviso antes de expirar, **retorno
automático na tela de sucesso**, e **horários de funcionamento** (abre/fecha,
sábado, domingo) — que alimentam a geração de slots.

---

## 2026-06-26 — /totem: overbooking inteligente (§1) + Remarcar por CPF funcional

### Overbooking inteligente (§1 NEW_FEATURE)
`Doctor` ganhou config de overbooking (`slotLimit`, `maxOverbook`, `maxPerSlot`,
`dayOverbook`, `periodOverbook`) e `capacityAt(weekday, hhmm)` —
`base + min(overbookDia, overbookPeríodo)` com teto rígido. O totem (`_buildSlots`)
agora conta agendamentos **ativos** por slot e calcula a **ocupação**; o
`_slotChip` reage com cores de intensidade (verde <50% / amarelo 50–79% /
vermelho 80–99% "ÚLTIMAS" / cinza "LOTADO" desabilitado) + legenda. Médicos mock
receberam configs variadas.

### Remarcar por CPF (funcional)
O passo `searchCpf` do Remarcar passou a **buscar de verdade**: localiza o paciente
por CPF (`fetchByCpf`), encontra o **agendamento ativo** dele e segue para escolher
novo horário (banner "REMARCANDO …"). Na confirmação, **move** o agendamento
existente (`AppointmentsNotifier.move` + `Appointment.copyWith` estendido para
médico/especialidade) em vez de criar um novo; o CPF não é pedido de novo. Sem
agendamento ativo, cai graciosamente para criar um novo. Tela de sucesso mostra
"Consulta Remarcada!".

---

## 2026-06-26 — /totem: busca de CPF no Firestore + tutorial passo-a-passo

### Busca de CPF (bug)
A verificação de CPF consultava a lista **mock** (`patientsProvider`), então
pacientes reais do Firebase davam "CPF não encontrado". Agora consulta a coleção
`users` do Firestore: novo `UserService.fetchByCpf` (FirestoreUserService faz
`where('cpf' == ...)` tentando CPF numérico **e** mascarado; MockUserService busca
nos pacientes mock). O totem usa `userServiceProvider.fetchByCpf` e passou a
trabalhar com `AppUser` no passo de confirmação.

### Tutorial "Como usar o totem" (UI/UX)
O `_TotemTutorialModal` (que listava os 4 passos de uma vez) virou um **tutorial
passo-a-passo** real: um passo por vez, ilustração grande, número + título +
descrição, **navegação Anterior/Próximo** (e "Pular"), **indicador de progresso**
animado, transições suaves e **layout responsivo** (largura adapta a telas
estreitas).

---

## 2026-06-26 — /totem: teclado numérico na tela para o CPF (agendar/remarcar)

O passo de CPF (compartilhado por Agendar/Remarcar) usava o teclado do sistema —
impróprio para um totem de toque. Substituído por um **teclado numérico na tela**
(`_numpad`): grade 3×4 (1–9, LIMPAR, 0, ⌫), visor grande com a máscara
`000.000.000-00`, teclas de dígito desabilitadas ao atingir 11, ⌫/LIMPAR
desabilitados quando vazio e **VERIFICAR** só habilita com 11 dígitos. Removido o
`_CpfFormatter` (não mais necessário).

---

## 2026-06-26 — /totem: correção do "Filtrar por médico" (horários não apareciam)

Ao filtrar por médico, os horários antes eram **removidos** dos demais (e, em
certas condições, a lista parecia vazia / confusa com horários duplicados entre
médicos). Agora segue o comportamento do projeto de referência: **todos os
horários permanecem visíveis**, o médico filtrado é **realçado e movido para o
topo** e os demais ficam **esmaecidos** (opacity). Cada horário também passa a
mostrar o **primeiro nome do médico** quando há mais de um, eliminando a
ambiguidade de horários iguais.

---

## 2026-06-26 — /totem: fluxo de agendamento completo (porte do projeto de referência)

### O que mudou
Reescrita do totem replicando o fluxo do projeto Next.js de referência
(`.specify/RECEPT_AGENDA-CLINICA-master/src/app/totem/*`), integrado aos dados
mock do app (médicos, pacientes, agendamentos):
- **Welcome** → Agendar / Remarcar consulta + "Testar impressão".
- **Schedule** → especialidade (derivada dos médicos), **semana** (7 dias),
  filtro por médico, **horários** gerados das agendas (08h–17h, sáb até 12h,
  dom fechado) descontando agendamentos existentes; **pré-reservados** (pendentes)
  em amarelo; cartão do profissional (foto/CRM/especialidades).
- **Confirm** → busca por **CPF** em `patients` → se existe, confirma os dados;
  senão, **cadastro** (nome/e-mail/telefone). Cria o agendamento
  (`AppointmentsNotifier.add`, status pendente) e gera **senha** `{inicial}{rand}`.
- **Success** → comprovante (senha grande, paciente, médico, especialidade, data,
  sala) com imprimir e voltar.
- **Sessão por inatividade** (2 min) com **aviso de 10s** ("Sessão Expirando!")
  e contador MM:SS no topo; qualquer toque renova; expira → volta ao início.
- UX: transições animadas, botões com feedback de toque, máscaras de CPF/telefone.

### Por quê
- Pedido: analisar o código/lógica do totem no projeto de referência e implementar
  tudo na `/totem`.

### Notas
- Slots/criação usam os **dados mock** (`doctorsProvider`, `appointmentsProvider`,
  `patientsProvider`); pronto para trocar pela fonte real. Impressão é simulada.
- `AppointmentsNotifier` ganhou `add(Appointment)`; `checkInAcolhimento` (versão
  anterior do totem-fila) segue disponível, mas a `/totem` agora é o agendamento.

---

## 2026-06-26 — /totem: autoatendimento funcional (gera senha → entra na fila)

### O que mudou
O totem deixou de ser uma casca estática (botões `onTap: () {}` mortos) e virou um
**fluxo de autoatendimento completo** (§3.1 — entrada de tickets via Totem),
integrado à fila da recepção.

- `totem_screen.dart` reescrito como `ConsumerStatefulWidget` com wizard:
  **boas-vindas** (Retirar senha / Tenho agendamento) → **tipo de atendimento**
  (linhas de cuidado) → **atendimento prioritário?** → **senha gerada**.
  Ao final, cria o ticket via `checkInAcolhimento(origin: 'TOTEM')`, mostra a
  **senha grande + protocolo + linha de cuidado + selo prioritário**, com imprimir
  e auto-retorno (countdown 18s).
- **UX**: transições animadas entre etapas, botões com feedback de toque (escala),
  contador de pessoas na fila no header, indicador de passos, botão Voltar, diálogo
  de instruções e **timeout de inatividade (60s)** que reseta para a tela inicial.
- **Provider**: `checkInAcolhimento` agora **retorna o ticket** e aceita `priority`
  (atendimento prioritário) e `origin`; a fila triada coloca **prioritários à
  frente** no mesmo nível de risco; nome vazio vira "Senha A0xx" (privacidade).
- Botão **"Abrir Totem"** adicionado no header da `/recepcao`.

### Por quê
- Pedido: implementar toda a lógica do totem do `NEW_FEATURE.md`, corrigir bugs e
  elevar a UI/UX.

### Notas
- A rota `/totem` segue o gate de auth do app (como o monitor). Para um totem
  realmente público (sem login) seria preciso liberar a rota no redirect.

---

## 2026-06-26 — Monitor: pausa com fila vazia + aviso antes da troca automática

- **Pausar quando a fila esvaziar** (`pauseWhenEmpty`, padrão on): o auto-avanço
  segura o contador enquanto não há ninguém aguardando; o chip mostra "Aguardando
  fila".
- **Aviso antes da troca** (`warnBeforeAdvance`, padrão on): nos 3s finais o chip
  fica vermelho/destacado e, com som ligado, toca um **bipe** (WAV gerado em memória
  e tocado via `AudioElement`; novo `beep()` no serviço de TTS, no-op fora da web).
- Novos switches na seção "CHAMADA AUTOMÁTICA" do painel (persistidos).

---

## 2026-06-26 — Monitor: config persistida + auto-avanço (chamar próximo com timer)

### O que mudou
- **Persistência**: a configuração do monitor agora é salva em SharedPreferences
  (`MonitorConfig.toJson/fromJson` + `providers/monitor_config_provider.dart`); a
  tela lê/grava via `monitorConfigProvider` (helper `_apply` escreve e persiste).
  Sobrevive a fechar/reabrir o monitor e reiniciar o app.
- **Chamar próximo automaticamente (timer)**: novos campos `autoAdvance` +
  `autoAdvanceSeconds` (5–120s). Com o auto-avanço ligado, o monitor chama o
  próximo da fila a cada intervalo; o timer reinicia a cada chamada manual. Nova
  seção "CHAMADA AUTOMÁTICA" no painel (switch + slider de intervalo) e um
  **contador regressivo** ("Próxima em Ns") na barra de controle.

### Por quê
- Pedido: salvar a personalização e adicionar opção de chamar o próximo
  automaticamente com um timer/intervalo configurável.

---

## 2026-06-26 — Monitor: personalização completa + foto do paciente

### O que mudou
Sistema de **configuração completa** do Monitor da Recepção (`models/monitor_config.dart`
— `MonitorConfig` + enums + paleta de tema + formatação de nome), editável por um
**painel lateral** (ícone `tune` → `endDrawer`):
- **Conteúdo**: foto do paciente (on/off), classificação de risco, local/guichê,
  atendente, relógio.
- **Foto do paciente**: `QueueEntry.photoUrl`/`CallRecord.photoUrl` (avatar com
  `Image.network` + fallback de iniciais); semeada em pacientes de exemplo.
- **Privacidade (LGPD)**: exibição do nome — Completo / Primeiro nome / Mascarado /
  Iniciais (aplicado em todos os painéis).
- **Aparência**: tema (Escuro / Claro / Alto contraste), cor de destaque, usar cor
  de risco como destaque, fundo com gradiente e **escala de fonte** (via
  `MediaQuery.textScaler`).
- **Voz**: ligar/desligar, velocidade, tom e **repetição** da locução (TTS agora
  aceita `rate`/`pitch`/`times`).
- **Comportamento**: animação de destaque, chamada automática, rolagem automática.
- **Layout**: densidade (Simples/Avançado/Lista) e orientação.
- Botão "Restaurar padrões". Os enums de layout migraram para `monitor_config.dart`.

### Por quê
- Pedido: personalização extremamente avançada do monitor, incluindo foto do paciente.

### Notas
- Config mantida na sessão da tela (não persiste em disco ainda). Fotos de exemplo
  usam `pravatar` (carregam só na web/online; há fallback de iniciais).

---

## 2026-06-26 — Recepção: Expandir (Fila Geral/Indicadores) + Kanban drag-and-drop

- **Expandir** padronizado (`widgets/fullscreen_helper.dart`) também na **Fila Geral**
  e **Indicadores** (conteúdo extraído em `FilaGeralTable`/`IndicadoresBoard` e
  reutilizado em `Dialog.fullscreen`).
- **Kanban**: arrastar-e-soltar entre colunas (`LongPressDraggable` + `DragTarget`),
  movendo o ticket de estado via novo `moveTo(id, status)` no provider (com destaque
  visual na coluna-alvo e registro na timeline).

---

## 2026-06-26 — Kanban: botão "Expandir" (tela cheia)

O quadro Kanban foi extraído para `KanbanBoard` (reutilizável) e a aba ganhou um
botão **"Expandir"** que abre o quadro em **tela cheia** (`Dialog.fullscreen` com
`Scaffold`/`AppBar` + fechar), mantendo o estado ao vivo via provider.

---

## 2026-06-26 — Monitor: modo Lista (auto-scroll) + correção de rolagem nas abas

### O que mudou
**Monitor — modo Lista:** novo layout `MonitorDensity.lista` (painel de chamadas).
Lista as chamadas já feitas (mais antigas→atuais), uma divisória "AGORA • HH:MM" e
os próximos da fila triada. A cada chamada (manual ou automática) **rola sozinho e
centraliza a chamada atual** (`ScrollController` + `_scrollToCurrent`, altura de linha
fixa). O botão de densidade do cabeçalho agora cicla Simples → Avançado → Lista.

**Correção de rolagem nas abas da /recepcao** (estouravam na vertical):
- Fila Geral, Meus Pacientes, Finalizados e Mural: as `DataTable` só rolavam na
  horizontal → agora têm **scroll vertical + horizontal** (SingleChildScrollView
  aninhado). No Mural a tabela passou a viver num `Expanded` e o header ficou
  protegido com `Expanded`.
- **Kanban**: cada coluna agora rola verticalmente de forma independente
  (`Row(stretch)` + `Expanded(ListView)`), em vez de estourar quando há muitos cards.

### Por quê
- Pedido: adicionar layout em modo lista que rola até a chamada atual; corrigir os
  erros de UI/UX e de rolagem nas abas (Meus Pacientes, Fila Geral, Kanban,
  Finalizados, Mural).

---

## 2026-06-26 — /recepcao: correções de layout, UX de alto nível e monitor multi-layout

### O que mudou
**Correções de layout (overflow):**
- KPIs de risco agora **responsivos** (`LayoutBuilder`+`Wrap`: 4/2/1 colunas) — antes
  era `Row` rígido de 4 `Expanded` (estourava em telas estreitas). Conteúdo interno
  do card protegido com `Expanded`/elipse.
- Header e tab bar já haviam migrado para `Wrap` (responsivos).

**UX:**
- **Busca funcional**: `recepcaoSearchProvider` + `filterBySearch` (nome/senha/
  protocolo); o campo de busca passou a filtrar Fila Geral, Meus Pacientes e
  Finalizados.
- **Aba Indicadores** (era placeholder) → painel operacional real: cards (em espera,
  em atendimento, atendidos hoje, **tempo médio de espera**), **aderência ao SLA**
  (% da fila estourada) e distribuições por **risco**, **linha de cuidado** e **tipo
  de demanda** (barras).
- **Meus Pacientes** e **Finalizados** modernizados ao padrão (faixa de cor de risco,
  rótulos em PT, linha de cuidado, selo **ATENDIDO/ENCAMINHADO**, vermelho de marca).

**Monitor da Recepção — 2 eixos de layout + chamada automática:**
- Alternância **Simples ↔ Avançado** e **Horizontal ↔ Vertical** (4 arranjos), via
  botões no cabeçalho do monitor.
- **Chamada automática**: `QueueEntry.scheduledAt` + `autoCallDue(now)` no provider;
  o monitor (a cada segundo, se "AUTO" ligado) chama sozinho o paciente **agendado
  quando chega o horário** (com locução). `callEntry(id)` faz a chamada direcionada.

### Por quê
- Pedido: corrigir erros de layout e elevar a UI/UX da `/recepcao`; no monitor,
  oferecer layouts simples/avançado e horizontal/vertical e **chamar automaticamente
  no horário do paciente**.

### Notas
- `scheduledAt` semeado em 1 agendamento (~40s à frente) para demonstrar o auto-call.

---

## 2026-06-26 — Monitor da Recepção (painel público de chamada + TTS)

### O que mudou
Implementado o **Monitor da Recepção** (`NEW_FEATURE.md` §4.1) — display público
de chamada de senhas em tela cheia.

- `recepcao_monitor_screen.dart` — tela cheia (fundo escuro, fora do shell de
  navegação): **senha em destaque**, nome do paciente, local/guichê e atendente,
  com cor de risco; **últimas chamadas**, **fila aguardando por cor de risco** e
  relógio. Animação de "pulso" a cada chamada; botões CHAMAR PRÓXIMO / RECHAMAR e
  alternância de som.
- **Locução (TTS)** via Web Speech API do navegador (`services/recepcao_tts*.dart`,
  import condicional: real na web, no-op nas demais plataformas). Frase no padrão
  do spec: "Paciente {nome}, favor dirigir-se a {local} com {atendente}".
- `models/call_record.dart` — `CallRecord` (senha, paciente, local, atendente,
  hora, risco) + frase de locução.
- `recepcao_provider.dart` — `calledHistory` + `callTick` (gatilho da locução);
  `callNext` registra a chamada; novo `recall([senha])` para rechamar.
- Rota top-level `/monitor-recepcao` (`AppRoutes.recepcaoMonitor`) e botão
  "Abrir Monitor" no header da `/recepcao`.

### Por quê
- Pedido: implementar o Monitor da Recepção do `NEW_FEATURE.md`.

### Notas
- Estado compartilhado in-memory: o monitor reflete as chamadas quando aberto na
  **mesma instância** do app (via navegação). `dart:html` é usado só no arquivo
  web-only (import condicional), sem afetar build mobile/desktop.

---

## 2026-06-26 — /recepcao: Acolhimento com Classificação de Risco (UBS/UPA/APS)

### O que mudou
A recepção foi adaptada à realidade de **UBS/UPA/APS** e padronizada no design
system da aplicação (`AppCard`, vermelho de marca `0xFFFF3B30`, pílulas/labels).

**Novos modelos (`features/recepcao/models/`):**
- `manchester_priority.dart` — `ManchesterPriority { red, orange, yellow, green }`
  com cor/`onColor`; a ordem define a urgência na fila (§1.3).
- `vital_signs.dart` — `VitalSigns` (PA, FC, Temp, SatO₂, glicemia, dor 0–10) +
  `suggestedPriority` (apoio à decisão: deriva a cor a partir dos vitais).
- `care_line.dart` — `CareLine` (geral, pré-natal, puericultura, HiperDia, saúde
  mental) e `AttendanceType` (espontânea/agendada).
- `timeline_event.dart` — `TimelineEvent {action, timestamp, details, agentId}`
  (jornada do paciente, §1.3).
- `patient_reputation.dart` — `PatientReputation`/`ReputationTier` (groundwork §5).

**`queue_entry.dart`** ganhou: `manchester`, `vitals`, `careLine`,
`attendanceType`, `microarea`, `acs` (vínculo eSF/ACS), `referral`, `timeline`;
`slaTarget` (tempo-alvo por cor: imediato/10/60/120 min) e `slaBreached(now)`.
Protocolo passou ao formato `YYMMDD+Random(1000-9999)` (§1.3).

**`recepcao_provider.dart`** — seed reescrito com casos reais de UBS (pré-natal,
HiperDia, saúde mental, vitais); `triagedQueue` (ordena por risco→chegada);
`riskCounts`; `checkInAcolhimento(...)` (acolhimento completo), `reclassify(...)`,
`refer(id, destino)` (referência → timeline + finaliza); `callNext` usa a fila
triada e registra timeline.

**UI:**
- `widgets/acolhimento_modal.dart` — formulário ACCR: identificação, tipo de
  demanda, linha de cuidado, **sinais vitais**, **classificação de risco**
  (chips Manchester com sugestão automática pelos vitais) e vínculo eSF/ACS.
- `recepcao_screen.dart` — header padronizado; KPIs agora por **cor de risco**
  (contagem em espera + alerta de **estouro de SLA**); "Novo Acolhimento" abre o
  modal.
- `tabs/fila_geral_tab.dart` — reescrita: faixa de risco, linha de cuidado, tipo
  de demanda, resumo de vitais, badge **SLA no prazo/estourado**, vínculo eSF, e
  ações ligadas (chamar, **encaminhar/referência**, concluir).
- `tabs/kanban_clinico_tab.dart` — borda e badge por cor de risco; coluna de
  espera ordenada pela fila triada.

### Por quê
- Pedido: padronizar o layout da recepção e adaptá-la à realidade de UBS/UPA/APS.
  Recursos escolhidos: classificação de risco Manchester, sinais vitais, demanda
  espontânea×agendada, linhas de cuidado, vínculo eSF/ACS e encaminhamento.

### Pendências
- Tudo em **mock/in-memory** (sem Firestore). Reputação (§5) e Painel/Totem+TTS
  (§4.1) ficaram fora deste escopo (groundwork de reputação criado, não exibido).
- `indicadores_tab`/`finalizados_tab` ainda refletem o domínio antigo de setores.

---

## 2026-06-26 — /admin-agentes: Gestão de Atendimento (agentes, filas, cadastro)

### O que mudou
Correção de bugs e implementação de recursos do `NEW_FEATURE.md` na página, na
arquitetura mock (Riverpod), no design system da aplicação.

**Correções de bugs:** botões "Ver Dashboard" (não navegava) e "Editar" (mudo)
da tabela de agentes; **exclusão** agora pede confirmação; overflow de layout;
modal de novo agente responsivo (90% em telas estreitas) + rolagem; cor de hint;
`DropdownButtonFormField.value`→`initialValue`; limpeza de cruft no header.

**§1.1 Agentes:** `AgentAvailability` passou a 4 estados (`online/busy/away/
offline`) com extensão de cor/rótulo; dropdowns da tabela **e** do
`agent_dashboard_screen` atualizados (corrige erro latente: valor sem item).
`agent_provider` ganhou `incrementLoad`/`decrementLoad`/`leastOccupiedFor`.

**§1.2 Setores/Filas (aba antes "em breve"):** `models/queue_model.dart`
(`DistributionStrategy least_occupied/round_robin`, `QueueSla`, agentes
vinculados), `providers/queue_provider.dart` (CRUD mock), `widgets/
queue_management_tab.dart` (cards no padrão da app: ícone vermelho, pílulas de
estratégia/SLA/contagem) e `widgets/queue_form_modal.dart` (criar/editar).

**§2.1 Cadastro atômico:** `services/agent_registration_service.dart` simula o
"Double Write" (checa unicidade, Auth bypass com PIN como senha, escrita em
`agents`+`users`) com `TODO(firebase)` nos pontos de integração. O modal de novo
agente usa o serviço (loading + SnackBar), permite selecionar filas e **gerar
novo PIN** (6 dígitos).

### Por quê
- Pedido: corrigir a página e implementar as funcionalidades do `NEW_FEATURE.md`
  ligadas a `/admin-agentes`, no padrão visual da aplicação.

### Pendências
- Mock/in-memory; integração real com Firebase Auth/Firestore marcada por
  `TODO(firebase)`. Fluxo de edição de agente ainda dá feedback "em breve".

---

## 2026-06-26 — /home: correções no carrossel de agendamentos

### O que mudou
`core/widgets/next_appointments_carousel.dart` (5 bugs):
- Setas ◀ ▶ não rolavam (`onTap` vazio) → convertido para `StatefulWidget` com
  `ScrollController` (animação com clamp e `dispose`).
- Horário duplicado no card → o lado direito agora mostra `Fmt.time(end)`.
- `_getInitials` podia lançar `RangeError` (nomes com espaço duplo/final) →
  filtra partes vazias.
- Borda do badge de tipo de consulta não respeitava o tema escuro → `borderDark`.
- Ícone do card usava cor de superfície (invisível no escuro) → `textTertiary`.

### Por quê
- Pedido: aprimorar e achar bugs no carrossel da `/home`.

---

## 2026-06-25 — /tarefas-agendadas escopada à clínica do usuário

### O que mudou
A página passava a clínica via `selectedClinicIdProvider` (a seleção da UI, que
pode estar desalinhada com a conta). Agora há `tarefasClinicaIdProvider`:
- usa a clínica **selecionada apenas se ela pertencer ao usuário** logado;
- senão, cai na 1ª clínica do perfil (`users.idclinica`).
Usado em: `scheduledTasksProvider` (lista), `task_modal` (criação) e
`ScheduledTasksRunner` (execução/catch-up). O `watch` ainda reforça com filtro
em memória `t.clinicaId == clinicaId`. Dados verificados via REST: as 4 tarefas
existentes são todas da clínica `JuhdNt7NG3GYOFKOKOXP` (a do usuário) e a query
por `clinicaId` retorna exatamente elas.

### Por quê
- Pedido: a página `/tarefas-agendadas` deve exibir **apenas o id da clínica do
  usuário** — independente da seleção/persistência da UI.

---

## 2026-06-25 — Cron: ações de escrita (criar/atualizar agendamento)

Adicionadas ao `scheduledTasksCron` (agora **19 ferramentas**):
- `atualizar_status_agendamento(id, status)` — valida o enum e **só altera se o
  agendamento pertencer à clínica do contexto** (trava multi-tenant via
  `belongsToClinic`).
- `criar_agendamento(...)` — cria em `tb_agendamentos` (status `confirmado`),
  com refs `idMedico`/`idClinica`/`idclinica`/`idPaciente`, dados desnormalizados
  e `dataConsulta` parseada (ISO ou `DD/MM/AAAA HH:MM` em BRT, via novo `parseDate`).
  Clínica travada no contexto.
Redeployado.

---

## 2026-06-25 — Cron: toolset ampliado (17 ferramentas)

### O que mudou
O agente do `scheduledTasksCron` passou de 5 para **17 ferramentas** (mais perto
da paridade com o app), todas escopadas por clínica:
- Leitura: `listar_agendamentos_hoje`, `buscar_paciente`, `listar_usuarios`,
  `listar_eventos_overbooking`, `listar_realocacoes`, `listar_tickets`,
  `listar_relatorios_ia`, `listar_email_logs`, `listar_email_queue`.
- Absenteísmo/IA (calculado de `tb_agendamentos`): `taxa_absenteismo`,
  `listar_agendamentos_risco_alto` (heurística RF-01), `historico_absenteismo_paciente`.
- Mantidas: `consultar_colecao`, `listar_agendamentos`, `listar_medicos`,
  `enviar_email`, `enviar_whatsapp`.
Helpers Node: `listScoped`, `fetchAgendamentos`, `quickScore`, `faltaRatios`.
Redeployado.

---

## 2026-06-25 — Cron real (servidor) para Tarefas Agendadas

### O que mudou
- **`cloud_functions/scheduledTasksCron.js`** — Cloud Function **agendada**
  (Gen 2, `onSchedule "*/5 * * * *"`, TZ America/Sao_Paulo) que executa as tarefas
  vencidas **mesmo com o app fechado**. Replica o lock/schema do cliente
  (`claimDue` em transação + avanço de `nextRunAt` + `finishRun` + `recoverStale`),
  então cron e catch-up do app **não duplicam** execuções.
- Agente Node chama o Azure DeepSeek (secret `AZURE_AI_KEY`) com ferramentas
  essenciais: `consultar_colecao`, `listar_agendamentos`, `listar_medicos`,
  `enviar_email` (SendGrid), `enviar_whatsapp` (Z-API por clínica). `kind=report`
  → `tb_scheduled_reports`; `kind=action` + `notifyEmail` → e-mail.
- **Deployado** no codebase `ia` (Cloud Scheduler/Pub-Sub habilitados).

### Por quê
- Pedido: executar as tarefas agendadas 24/7 sem depender do app aberto.

### Pendências
- O agente do cron usa um **subconjunto** de ferramentas (Node) vs. o catálogo MCP
  completo do app (Dart). Paridade total exigiria portar mais tools ou usar o MCP
  do backend existente.
- Node 20 será descontinuado em 2026-10-30 (avisos de deploy).

---

## 2026-06-25 — Tarefas Agendadas (TAREFAS_AGENDADAS.md) — versão Flutter

### O que mudou
Implementado o módulo **Tarefas Agendadas** (`/tarefas-agendadas`) — versão
client-side do spec (sem Vercel Cron; execução por catch-up ao abrir + "executar
agora", usando o agente de IA já existente).

**`lib/features/tarefas_agendadas/`:**
- `schedule_util.dart` — `TaskSchedule` + `computeNextRun`/`describeSchedule`/
  `validateSchedule`/`parseFlexibleDate` (BRT fixo UTC-3); lê tanto o schema da
  spec quanto o gravado pelas tools MCP (`recorrencia`/`horario`/`diasSemana`…).
- `scheduled_task.dart` — modelo `ScheduledTask` + `RunRecord` (`tb_scheduled_tasks`).
- `scheduled_tasks_service.dart` — CRUD + **lock atômico** (`claimDue`/`finishRun`/
  `lockForManualRun`/`recordManualRun`/`recoverStale`) em transação Firestore,
  histórico (máx 20), término automático (once/maxRuns/endAt). Escopo por clínica.
  Providers: `scheduledTasksServiceProvider`, `scheduledTasksProvider` (stream).
- `scheduled_tasks_runner.dart` — executor: roda as tarefas vencidas/agora via
  `AiAgentService` + MCP (timeout 4 min). `kind=report` salva em
  `tb_scheduled_reports`; `kind=action` com `notifyEmail` enfileira em `email_queue`.
- `tarefas_agendadas_screen.dart` + `widgets/task_modal.dart` — UI: lista (status,
  scheduleLabel, próxima/última, contadores), executar/pausar/retomar/editar/
  excluir, histórico expansível; modal criar/editar (once/interval/daily/weekly/
  monthly). Catch-up ao montar.

**Wiring:** rota `/tarefas-agendadas` (app_router), `AppRoutes.tarefasAgendadas`,
item no drawer (nav_destinations).

### Por quê
- Pedido: implementar `TAREFAS_AGENDADAS.md`. As tools MCP (§11) já existiam; faltavam
  a página, a lógica de agendamento/lock e o executor — agora no app Flutter.

### Pendências / notas
- Não há cron de servidor (Vercel) — a execução autônoma depende de o app abrir a
  página (catch-up) ou "executar agora". Para execução 24/7 seria preciso uma
  Cloud Function agendada chamando o mesmo agente.
- RBAC (admin/rsa) do spec não é forçado na UI (a rota segue o gate geral do app).

---

## 2026-06-25 — Busca global (Ctrl+K) aprimorada + correção de bugs

### Bugs corrigidos (`core/widgets/command_palette.dart`)
- **Navegação por teclado quebrada:** o `KeyboardListener` usava um `FocusNode()`
  sem foco (e vazado) → ↑/↓/Enter/Esc não funcionavam. Agora a navegação é
  tratada via `focusNode.onKeyEvent` do próprio campo (retorna
  `KeyEventResult.handled`), preempção correta sobre a edição de texto.
- **Rebuild O(n²):** `_buildListItems(grouped)` era chamado para o `itemCount` e
  **de novo a cada item** no `itemBuilder`. Agora é construído uma vez por frame.

### Melhorias
- **Ranking por relevância** (`_scoreItem`): título exato > prefixo > início de
  palavra > substring; depois subtítulo e palavras-chave. Resultados ordenados
  por score (em vez de só `contains`).
- **Entidades reais na busca:** além de módulos e ações, agora indexa as
  **clínicas do usuário** (`userClinicsProvider`, respeita o multi-tenant) —
  selecionar troca a unidade ativa; marca a "Atual".
- **Auto-scroll** para manter o item destacado visível ao navegar; suporte a
  Enter do teclado numérico.

---

## 2026-06-25 — Autocomplete de atalhos no input do chat e dos agentes

### O que mudou
- `agent/ia_suggestions.dart` — catálogo de atalhos por categoria (Agendamentos,
  Médicos, Pacientes, Riscos & IA, Overbooking, E-mails, Relatórios, WhatsApp,
  Tickets, Tarefas Agendadas) + `filterSuggestions(query)`.
- `widgets/ia_suggestions_panel.dart` — painel de autocomplete (ícone + título da
  categoria + sugestões clicáveis), filtrado pelo texto digitado.
- Integrado no `AiChatPanel` e no `AiAgentsPanel`: ao focar o campo, o painel
  aparece acima do input; digitar filtra; clicar preenche o input (mantém foco).
  Inputs ganharam `FocusNode`.

### Por quê
- Pedido: autocomplete com atalhos de exemplo na barra de pergunta do chat e do
  agente de IA.

---

## 2026-06-25 — Correção (raiz): idclinica do usuário não carregava

### Diagnóstico (dados reais inspecionados via REST autenticado)
Login `contato@agendaclinicas.com.br` → uid `RqHgOFrLw2NG8wUZnOIvzyZutsd2`.
Existe `users/RqHgOFrLw2NG8wUZnOIvzyZutsd2` (doc id = uid) com
`idclinica → tb_clinica/JuhdNt7NG3GYOFKOKOXP` ("Agenda Clínica"). Dois bugs
impediam o carregamento:

1. **`FirestoreUserService.fetchByUid`** fazia `where('uid'==)` ANTES do
   `doc(uid).get()`. As regras do Firestore permitem `get` do próprio doc, mas
   **bloqueiam list/queries** em `users` → a query lançava exceção que o
   `try/catch` do `load()` engolia → usuário ficava mock (sem clínica) → caía na
   1ª clínica (AXL). **Fix:** `doc(uid).get()` primeiro; `where` em try/catch.
   `fetchByEmail` também tolerante a queries bloqueadas.
2. **`Clinic.fromFirestore`** fazia `data['endereco'] as Map` — mas neste
   cadastro `endereco` é **String** → `TypeError` → `watchClinics` descartava o
   doc → a clínica vinculada sumia da lista → filtro por `idclinica` vazio →
   clínica errada. **Fix:** cast seguro (`is Map ? ... : {}`).

### Resultado
`fetchByUid` agora retorna o perfil real (clinicIds = `[JuhdNt7NG3GYOFKOKOXP]`) e
a clínica "Agenda Clínica" aparece em `tb_clinica` (list permitido, confirmado),
então o cabeçalho/escopo passam a usar a clínica correta.

---

## 2026-06-25 — Correção: login caindo em outra conta/clínica (AXL)

### O que mudou
Ao logar com um e-mail cujo `uid` do Firebase Auth **não casava** com o `uid`
gravado em `users`, o perfil não era encontrado e o app caía no usuário mock
sem clínica → o cabeçalho mostrava a **primeira clínica de todas** (ex.: "AXL
Comunicação LTDA"), exibindo dados de outra conta.

Correções:
- `UserService.fetchByEmail` (novo) + `FirestoreUserService`: busca o perfil por
  **e-mail** (chave estável compartilhada entre Auth e `users`), com tentativa
  case-insensitive.
- `CurrentUserNotifier.load(uid, email)`: tenta por `uid` e, se falhar, por
  e-mail; se nada for encontrado, não exibe dados de outra conta.
- `SelectedClinicNotifier._getDefault`: só aceita a clínica persistida se ela
  **pertencer ao usuário atual** — evita vazar a clínica de um login anterior.

### Por quê
- Bug reportado: login com `contato@agendaclinicas.com.br` exibia "AXL
  Comunicação LTDA" (conta/dados errados).

### Observação
- Requer que exista um documento em `users` com o `email` correspondente. Para
  contas sem registro em `users`, ainda é necessário criar/migrar o perfil.

---

## 2026-06-25 — Página /ia 100% funcional + deploy das Cloud Functions

### O que mudou
**Deploy** (codebase `ia` isolado, não afeta as functions existentes): publicadas
`chatProxy`, `emailProxy`, `whatsappProxy`, `analyzeDocument` em us-central1, com
secrets `AZURE_AI_KEY`/`AZURE_DOCINTEL_KEY`/`SENDGRID_API_KEY` (e placeholder
`ANTHROPIC_API_KEY`). `chatProxy` testado ponta-a-ponta (DeepSeek respondeu).
Scaffold criado: `functions/` (index.js + package.json), `firebase.json`,
`.firebaserc`. Isso resolve o erro "Failed to fetch" do chat.

**Todos os recursos da /ia agora funcionais** (antes vários eram mock):
- **Providers de sessão** (`agent/ia_session.dart`): `iaViewProvider` (toggle
  Chat/Agentes compartilhado), `iaSearchProvider`, `agentTimeoutProvider`,
  `pendingAttachmentsProvider`.
- **Persistência de conversas** (`agent/ia_chats_service.dart`, `tb_ia_chats`):
  o chat salva cada conversa (multi-tenant); `agentChatProvider` ganhou
  `newConversation()` e `loadConversation(id)`.
- **Alertas reais** (`agent/ia_alerts_provider.dart`): varre e-mails com erro e
  overbooking 24h (escopo da clínica), a cada 60s; chips clicáveis abrem o tema
  no chat.
- **Barra superior** (`ai_dashboard_main_area.dart`): nome real da clínica +
  e-mail do usuário; menu abre o drawer; engrenagem vai p/ `/configuracoes`;
  toggle via provider.
- **Sidebar esquerda** (`ai_dashboard_left_sidebar.dart`): busca funcional, "Nova
  conversa", histórico real de conversas (clicável p/ carregar) e planos salvos
  reais (clicável → síntese).
- **Sidebar direita** (`ai_dashboard_right_sidebar.dart`): status real (contagem
  MCP, Firebase), slider de timeout ligado ao orquestrador, painel de anexos real.
- **Orquestrador**: aplica o timeout por agente do slider.

### Por quê
- Pedido: "todos os recursos da página /ia funcionais" + destravar o chat (deploy).

### Pendências
- `anthropicProxy` não publicado (chave Anthropic é placeholder).
- Node 20 nas functions será descontinuado em 2026-10-30 (avisos de deploy).

---

## 2026-06-25 — Proxy: envio direto de WhatsApp (Z-API)

### O que mudou
- **`cloud_functions/whatsappProxy.js`** — Cloud Function que envia WhatsApp
  **direto** via Z-API, lendo as credenciais **por clínica** de
  `tb_config_whatsapp` (`intanceId`/`token`/`tokenCliente`/`idclinica`) com o
  Admin SDK (nenhuma credencial no cliente). Suporta `send-text` e
  `send-button-list`.
- **`comunicacao_tools.dart`** — o helper `_writeWhatsapp` agora **envia de
  verdade**: POST ao `whatsappProxy` com `clinicaId`/`phone`/`message`/`buttons`
  e grava log em `tb_conversas` (`status: 'enviado'`; em falha, `'enfileirado'`).
  Carimba `idclinica`.

### Por quê
- Continuação do pedido: ligar o envio direto de WhatsApp (análogo ao de e-mail).

### Pendências
- Requer `tb_config_whatsapp` preenchido por clínica (instância Z-API conectada).
- Deploy: `firebase deploy --only functions:whatsappProxy` (sem secrets).

---

## 2026-06-25 — Proxies: envio direto de e-mail (SendGrid) e provedor Anthropic

### O que mudou
- **`cloud_functions/emailProxy.js`** — Cloud Function que envia e-mail **direto**
  via SendGrid (secret `SENDGRID_API_KEY`). A camada MCP passou a **enviar de
  verdade**: o helper `_enqueueEmail` (em `comunicacao_tools.dart`) agora faz POST
  ao `emailProxy` e grava log em `email_queue` com `status: 'sent'`; se o proxy
  falhar, mantém `'queued'` (fallback `ffProcessEmailQueue`). Adicionados helpers
  `_emailSubject`/`_emailBody` para derivar assunto/corpo por `tipo`. Continua
  carimbando `idclinica` (isolamento).
- **`cloud_functions/anthropicProxy.js`** — alternativa ao DeepSeek: aceita o
  mesmo contrato OpenAI (messages/tools/tool_calls) e traduz ↔ API Messages da
  Anthropic (Claude). No app, `AiAgentService.anthropicProxyUrl` permite trocar o
  provedor (`AiAgentService(proxyUrl: ...)`).
- **`chatProxy.js`/`analyzeDocument.js`** — endpoints alinhados às chaves
  atualizadas (`AI_chaves.md`): DeepSeek `/openai/v1/chat/completions`;
  Document Intelligence `micro-mpfiisv0-eastus2.cognitiveservices.azure.com`.

### Por quê
- Pedido do usuário (após atualizar `AI_chaves.md`): criar proxy de envio direto
  via SendGrid e proxy Anthropic como alternativa ao DeepSeek; chaves no servidor.

### Pendências
- Deploy: `emailProxy` (`SENDGRID_API_KEY`) e `anthropicProxy` (`ANTHROPIC_API_KEY`
  — ainda placeholder em `AI_chaves.md`, definir chave real).
- `http` passou a ser usado também na camada MCP (`comunicacao_tools.dart`).

---

## 2026-06-25 — AGENT TEAMS: Voz (STT), Anexos/OCR e Persistência de planos/relatórios

### O que mudou
Três frentes do AgentAI.md (§7.1.2, §7.2/§7.3) implementadas **em paralelo por
agent teams** (cada agente em arquivos isolados; o líder integrou no input do
chat e no sidebar).

**Voz (STT):**
- `agent/voice_input_service.dart` — wrapper do `speech_to_text` (pt_BR, parcial+final).
- `widgets/voice_mic_button.dart` — botão de microfone (pulsa ao ouvir; esmaece
  se indisponível no navegador/dispositivo).

**Anexos + OCR:**
- `agent/document_service.dart` — `.txt/.md/.csv/.json` lidos no cliente; PDF/imagem/
  Office vão por proxy. `widgets/attachment_button.dart` — seleção via `file_picker`,
  extrai texto e injeta como `[Contexto do documento]` na próxima mensagem.
- `cloud_functions/analyzeDocument.js` — Cloud Function (Azure Document
  Intelligence `prebuilt-read`), chave em secret `AZURE_DOCINTEL_KEY` (server-side).

**Persistência de planos/relatórios:**
- `agent/agent_plans_service.dart` — grava `tb_agent_plans` (plano multi-agente),
  `tb_relatorio_ia` e `tb_scheduled_reports` (relatórios), **carimbando `idclinica`**
  (isolamento); providers `savedPlansProvider`/`savedReportsProvider` (filtram por
  clínica, ordenam em memória). `widgets/saved_plans_panel.dart` lista o histórico.
- `agent/agent_orchestrator.dart` — ao concluir, salva plano + relatório (try/catch,
  não quebra a UX).

**Integração (líder):**
- `widgets/ai_chat_panel.dart` — input ganhou botões de **anexo** e **microfone**
  + chips de anexos pendentes (removíveis); o conteúdo dos anexos é enviado como
  contexto junto da mensagem.
- `widgets/ai_dashboard_right_sidebar.dart` — nova seção "HISTÓRICO (PLANOS &
  RELATÓRIOS)" com o `SavedPlansPanel`; contagem do MCP corrigida (70 ferramentas).
- **Dependências:** `speech_to_text: ^7.0.0`, `file_picker: ^8.1.6`.

### Por quê
- Pedido do usuário: voz/anexos (OCR) + persistência de planos/relatórios, usando
  agent teams; credenciais conforme `.specify/api-key.js` (Firebase) — chaves de
  IA/OCR ficam no servidor (Cloud Functions).

### Pendências
- Deploy das Cloud Functions `chatProxy` e `analyzeDocument` (+ secrets
  `AZURE_AI_KEY` / `AZURE_DOCINTEL_KEY` e `AZURE_DOCINTEL_ENDPOINT`).
- Permissões nativas de microfone **adicionadas**: Android `RECORD_AUDIO` +
  `INTERNET` + `<queries>` para `android.speech.RecognitionService`; iOS
  `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription`.

---

## 2026-06-25 — Modo Agentes (orquestrador multi-agente) na /ia

### O que mudou
Implementado o **modo Agentes** (AgentAI.md §7.1.4) — o toggle "AGENTES" da `/ia`
deixou de ser mockup e virou um orquestrador real: **plano → execução paralela
→ síntese em streaming**.

**Novos arquivos (`lib/features/ia/`):**
- `agent/agent_orchestrator.dart` — `agentOrchestratorProvider` (StateNotifier):
  fases `planning → executing → synthesizing → done`. Executa as tarefas em
  **lotes de 4** em paralelo (`Future.wait`), cada uma com acesso às ferramentas
  MCP (isolamento por clínica mantido).
- `widgets/ai_agents_panel.dart` — UI: objetivo, banner de fase, **cards de
  tarefa** expansíveis (status idle/running/✓/✗, badge "Pro"), e bloco de
  **síntese executiva** com markdown + gráficos.
- `widgets/ai_rich_content.dart` — renderer compartilhado (markdown + ` ```json-chart `).

**Estendido:**
- `agent/ai_agent_service.dart` — `plan(objetivo)` (planner decompõe em 2–6
  tarefas, JSON), `runToString(...)` (executa uma tarefa e retorna o texto final).
- `agent/agent_models.dart` — `PlanTask`, `TaskStatus`.
- `widgets/ai_dashboard_main_area.dart` — `_buildAgentesView()` usa `AiAgentsPanel`.

### Por quê
- Continuação do chat de IA: o usuário pediz o próximo recurso (modo Agentes).
  Reusa o mesmo `AiAgentService`/Cloud Function proxy e o catálogo MCP.

### Pendências
- Depende do mesmo deploy da Cloud Function `chatProxy` (já documentado).
- Persistência de planos (`tb_agent_plans`), retry configurável e export (PDF/
  e-mail) ainda como evolução. Entrada por voz/anexos também pendente.

---

## 2026-06-25 — Chat de I.A na página /ia (agente + loop de ferramentas MCP)

### O que mudou
Implementado o **chat do agente de IA** (`.specify/AgentAI.md`) na página `/ia`,
substituindo o mock estático por uma conversa real com loop de ferramentas MCP.

**Novos arquivos (`lib/features/ia/`):**
- `agent/agent_models.dart` — `ChatMessage`, `ToolCall`, `ChatRole` + serialização
  no formato OpenAI/Azure (tool_calls, role=tool).
- `agent/ai_agent_service.dart` — cliente do agente: fala com a **Cloud Function
  proxy** (`chatProxy`) que chama o Azure DeepSeek V4. Implementa o **loop de
  ferramentas** (até 6 rodadas) emitindo eventos `thinking`/`tool_done`/`token`/
  `done`/`error`; converte os specs MCP em function-calling da OpenAI; system
  prompt com o `clinicaId` e o contrato do bloco ` ```json-chart `.
- `agent/agent_controller.dart` — `agentChatProvider` (StateNotifier) que
  orquestra a conversa e executa as tools via `mcpServerProvider` (isolamento
  por clínica preservado).
- `widgets/ai_chat_panel.dart` — UI do chat: lista de mensagens, **chips de
  tool calls** (piscam ao executar, viram ✓/✗), markdown, streaming, cartões de
  sugestão e barra de input.
- `widgets/ai_chart_view.dart` — renderiza blocos ` ```json-chart ` com **fl_chart**
  (bar/line/pie).
- `widgets/ai_dashboard_main_area.dart` — o `_buildChatView()` agora usa o
  `AiChatPanel`.

**Backend (para deploy pelo usuário):**
- `cloud_functions/chatProxy.js` — Cloud Function (Gen 2, HTTPS) que faz proxy
  seguro ao Azure DeepSeek; a **chave fica só no servidor** (secret `AZURE_AI_KEY`)
  e o CORS é resolvido na função (funciona na web). + `cloud_functions/README.md`
  com instruções de deploy.

**Dependência:** adicionado `http: ^1.2.2`.

### Por quê
- Pedido: implementar o chat de IA do AgentAI.md na página `/ia`. A escolha de
  arquitetura (decisão do usuário) foi **proxy via Cloud Function** — seguro e
  compatível com o navegador (sem CORS, sem chave no cliente).

### Pendências / próximos passos
- ⚠️ Requer **deploy da Cloud Function `chatProxy`** + secret `AZURE_AI_KEY`.
  Enquanto não publicada, o chat mostra erro amigável orientando o deploy.
- Modo **Agentes** (multi-agente/orquestrador), entrada por voz (STT), anexos/OCR
  e alertas em tempo real (RF-14..RF-16) ainda como evolução.
- Recomendado validar App Check / ID token no proxy para evitar abuso.

---

## 2026-06-25 — AGENT TEAMS: Camada MCP em Dart (~50 tools) + isolamento por clínica

### O que mudou
Implementada a camada **MCP** (`.specify/MCP.md`) como código Dart nativo em
`lib/core/modules/mcp/`, espelhando a factory `createMcpServer` e o catálogo de
~50 ferramentas do servidor Node original — porém rodando dentro do app Flutter,
contra o mesmo Firestore (`agendaclinica-457713`).

**Núcleo compartilhado:**
- `mcp_tool.dart` — `McpTool` (name/description/inputSchema/handler), `McpResult`
  + helpers `ok()`/`err()`/`jsonSafe()`, e `McpContext` (multi-tenant: `db`,
  `defaultClinicaId`, `clinicaId()`, `docRef`, `toJsonList`/`toJsonOne`, `limit`,
  `belongsToClinic`, `isForeignClinic`, `clinicRef`) + extensão `McpArgs`.
- `mcp_cache.dart` — cache em memória com TTL (porta de `mcp-cache.js`).
- `mcp_server.dart` — `createMcpServer({db, defaultClinicaId})` + `McpServer`
  (`callTool`, `listToolSpecs`, `toolNames`). Registra todos os grupos.
- `mcp_providers.dart` — `mcpServerProvider` (escopado na clínica ativa via
  `selectedClinicIdProvider`) e `mcpToolSpecsProvider`.

**Grupos de ferramentas (implementados em paralelo por 6 agentes, 1 arquivo cada):**
- `tools/clinicas_medicos_tools.dart` (§6.1, §6.2) — 4 tools.
- `tools/agendamentos_tools.dart` (§6.3) — 5 tools (inclui `criar_agendamento`).
- `tools/pacientes_risco_tools.dart` (§6.4, §6.5, §6.12) — 12 tools (motor de
  risco RF-01 calculado a partir de `tb_agendamentos`).
- `tools/overbooking_sus_tools.dart` (§6.6, §6.7, §6.13) — 13 tools.
- `tools/dados_tools.dart` (§6.8–§6.11, §6.18) — 15 tools.
- `tools/comunicacao_tools.dart` (§6.14–§6.17) — 21 tools.

### 🔒 Isolamento multi-tenant (requisito do usuário)
> "Todo acesso ao sistema via MCP deve ser apenas pelo ID da clínica; o usuário
> só pode acessar os dados da clínica dele."

Implementado em camadas:
1. **Lock de escopo:** `McpContext.clinicaId()` **ignora** qualquer `clinicaId`
   vindo dos argumentos (do LLM) e sempre retorna a clínica do contexto. Nenhuma
   tool consegue operar em outra clínica, mesmo aceitando o parâmetro.
2. **Filtro central de leitura:** `toJsonList`/`toJsonOne` descartam
   automaticamente documentos de **outra** clínica (`isForeignClinic`) — protege
   todas as tools de listagem/busca de uma só vez.
3. **Casos sem campo de clínica:** `listar_clinicas` retorna só a clínica do
   usuário; `buscar_clinica` nega ID fora do escopo; `consultar_colecao` (genérica)
   retorna apenas documentos que comprovadamente pertencem à clínica.
4. **Escrita carimbada:** filas de e-mail/WhatsApp (`email_queue`, `tb_conversas`)
   gravam `idclinica` = clínica do usuário.

### Por quê
- Pedido: "implementar todas as funcionalidades do MCP usando agent teams" +
  regra de isolamento por clínica. O agente de IA do app passa a ter um catálogo
  real de ferramentas seguras, multi-tenant, sem depender do backend Next.js.

### Decisões / pendências
- ⚠️ Envios externos (SendGrid, Z-API, Google, Cloud Functions) **não** chamam
  endpoints direto (sem `http`, sem segredos no cliente — regra do projeto):
  as tools **enfileiram** em `email_queue`/`tb_conversas`/`google_tasks` (já
  processadas por Cloud Functions como `ffProcessEmailQueue`).
- ❌ Loop de ferramentas com LLM ao vivo (Azure DeepSeek) **pendente** — exige
  proxy via Cloud Function. `mcpServerProvider`/`mcpToolSpecsProvider` já expõem
  tudo que o `agent-runner` precisará.
- Coleções novas usadas: `tb_lista_espera`, `tb_agent_config`,
  `tb_scheduled_tasks`, `google_tasks`.
- `flutter analyze lib/core/modules/mcp` → **No issues found**.

---

## 2026-06-24 — AGENT TEAMS: 4 novos módulos + auditoria

### O que mudou
Auditoria do projeto e atualização do `.specify/AGENTS.md` com a seção
"Roadmap de Melhorias e Recursos Avançados". 4 módulos implementados em
**paralelo por agentes** (cada um isolado em sua pasta) e integrados pelo líder:

- **Pacientes** (`features/pacientes/`) — lista com busca/filtro de risco +
  detalhe/jornada (timeline, histórico, notas clínicas, ações). Rota `/pacientes`.
- **Recepção** (`features/recepcao/`) — check-in, fila com tempo de espera,
  painel de senha (chamar próximo) e KPIs do balcão. Rota `/recepcao`.
- **Central de Notificações** (`features/notificacoes_centro/`) — feed com
  filtros, marcar como lida e `unreadCountProvider` (badge no cabeçalho). Rota `/notificacoes`.
- **Relatórios** (`features/relatorios/`) — lista, detalhe e exportação
  (Copiar/CSV/Imprimir), gerar via IA. Rota `/relatorios`.

Integração (líder): rotas no `app_router`, entradas no drawer/rail
(`nav_destinations`), entradas no `ModuleRegistry` (Recepção → implementado;
+ pacientes, relatorios, notificacoes), e **sino de notificações com badge** no
`AppHeader` ligado ao `unreadCountProvider`.

### Por quê
- Pedido: auditar melhorias/recursos faltantes, atualizar specs e implementar
  usando agent teams. Os novos módulos preenchem lacunas previstas no AGENTS.md
  (pacientes/jornada, recepção, notificações, relatórios).

### Mapeamento de coleções (isolamento mantido — validado por teste)
- pacientes → owned `tb_historico`; lê `users`, `patient_reputation`.
- recepcao → owned `queue_realoc`, `tb_confirmationHistory`.
- notificacoes → owned `ff_user_push_notifications`, `notices`; lê `ff_push_notifications`.
- relatorios → lê `tb_relatorio_ia`, `tb_faltas_data` (sem escrita dedicada).

### Pendências
- ❌ Persistência real (Firestore) dos novos módulos — hoje mock local.
- ❌ Geração de PDF real nos Relatórios (CSV/impressão simulados).

---

## 2026-06-24 — Planos vindos do Firestore (`tb_plans`)

### O que mudou
A tela `/choose-plan` passou a carregar os planos da coleção **`tb_plans`** do
Firestore, no lugar dos planos mock fixos.

- Dependência `cloud_firestore`.
- `PlanService` (abstração) com `FirestorePlanService` (lê `tb_plans`) e
  `MockPlanService` (offline/testes).
- `Plan.fromFirestore` mapeia: `nome`, `descricao`, `precoMensal`/`precoAnual`
  (ou `inter_preco_mes`/`inter_preco_ano`), `recursosInclusos` (string → lista)
  + `beneficiosAdicionais` (array), `isPopular`, `limiteUsuarios`,
  `limite_consulta`, `nivelSuporte`, `intergracao`. Filtra `status` inativo e
  ordena por preço mensal.
- `plansProvider` agora inicia com os planos mock e é **substituído pelos dados
  reais** assim que carregam (UI atualiza reativamente; consumidores síncronos
  seguem funcionando). Fallback para mock em caso de falha de rede.
- `main.dart` injeta `FirestorePlanService` quando o Firebase inicializa.

### Por quê
- AGENTS.md › "Escolher plano": os planos disponíveis devem vir de `tb_plans`.
  Agora os preços e recursos exibidos refletem o catálogo real do projeto.

### Observações
- O vínculo do plano escolhido ainda é cacheado localmente; a gravação em
  `tb_plan_user` e a leitura de limites em `tb_limit_app` permanecem pendentes.
- Os nomes de campo de preço variam nos documentos (`precoMensal` vs
  `inter_preco_mes`); o mapeamento aceita ambos.

---

## 2026-06-24 — Métodos de login na página de login

### O que mudou
Na tela de login (`features/auth/login_screen.dart`) foram adicionados, com
degradação graciosa quando "não configurado":

- **Login biométrico** (digital / Windows Hello) — `BiometricService`
  (`local_auth`). O botão "Entrar com digital" só aparece quando o dispositivo
  tem biometria E o usuário a habilitou E existe sessão salva. Após o 1º login
  por senha, o app oferece ativar a digital.
- **Login com Google** — `AuthService.signInWithGoogle()` via Firebase
  (`signInWithPopup` na web, `signInWithProvider` no mobile). Também no cadastro.
- **Primeiro acesso** — card em destaque levando ao cadastro/configuração.
- **Banner de modo demonstração** — exibido quando o Firebase não inicializa
  (`AuthService.isFirebaseEnabled == false`), explicando o que habilitar.

Preferências novas: `auth_biometric_enabled` (bool).

### Por quê
- AGENTS.md › LOGIN pede recuperação de senha, **cadastro biométrico (digital)**
  e **login/cadastro com Google**; e o requisito do usuário: "se o usuário não
  tiver configurado, implementar na página de login". A UI agora detecta o que
  está disponível e oferece a alternativa correta, sem quebrar quando um método
  não está configurado (biometria ausente, Firebase off, asset de logo ausente).

### ⚠️ Configuração necessária para produção
- Habilitar provedores **Email/Password** e **Google** em Firebase Authentication.
- Web: adicionar o domínio autorizado; mobile: SHA-1/SHA-256 (Android) e
  `flutterfire configure` para `google-services.json`/`GoogleService-Info.plist`.
- Biometria: `local_auth` requer permissões nativas (USE_BIOMETRIC no Android,
  NSFaceIDUsageDescription no iOS). Não há suporte em navegador.

---

## 2026-06-24 — Editor de Logotipo (Configurações)

### O que mudou
Nova seção "Logotipo" em `/configuracoes` (`logo_editor_screen.dart`):

- Enviar imagem (`image_picker`), trocar e remover.
- **Limpar fundo automaticamente** (remoção heurística do fundo uniforme → transparente).
- **Corte inteligente** (auto-trim para a bounding box do conteúdo).
- **Escala/zoom** (recorte central 100–300%), tamanho de saída (128/256/512px),
  formato circular e **filtros inteligentes** (Original, Realçar, P&B, Marca/duotone).
- Processamento via pacote `image` (`LogoProcessor`); preview com fundo xadrez.
- O logo é salvo como PNG base64 em `AppSettings.logoBase64` e exibido no
  **login**, no **drawer** e onde o brand aparece.

### Por quê
- Pedido do usuário: editar o logo (tamanho, escala, corte, limpar fundo,
  filtros e cortes inteligentes) direto nas Configurações.

### Observações
- Processamento roda no cliente (sem ML pesado); a remoção de fundo funciona
  melhor com fundos uniformes. Upload para Storage/Firestore: ❌ pendente
  (hoje persiste local em `app_settings`).

---

## 2026-06-24 — Módulo 9: Configurações do Sistema

### O que mudou
Implementado o módulo `features/configuracoes/` (CFG-01 a CFG-07):

- **Modelo** `AppSettings` (aparência, tipografia, tema, acessibilidade,
  notificações, avançado) com `toJson/fromJson` e `defaultsFor(ClinicType)`.
- **Provider** `settingsProvider` persistindo em SharedPreferences (`app_settings`).
- **Tema reativo**: `AppTheme.fromSettings` aplica cor primária/destaque, fonte
  (google_fonts), escala, espaçamento, cantos (borderRadius), contraste e modo
  claro/escuro. `app.dart` passou a `ConsumerWidget` e aplica também `textScaler`,
  filtro de daltonismo (`ColorFilter`) e redução de movimento.
- **Telas**: hub + Aparência (CFG-01), Tipografia (CFG-02), Tema (CFG-03),
  Acessibilidade (CFG-04), Notificações (CFG-05), Dados e Privacidade (CFG-06)
  e **Avançado (CFG-07)** — idioma, formato de data/hora, fuso, modo
  desenvolvedor (7 toques na versão), sobre/licenças e restaurar padrões.
- Rota `/configuracoes`, atalho no drawer e entrada no `ModuleRegistry`
  (`configuracoes`, owned: `tb_limit_app`).

### Por quê
- Atende ao "Módulo 9 — Configurações do Sistema" do AGENTS.md. Persistência
  local primeiro (resposta instantânea); sincronização com `tb_limit_app`/`users`
  no Firestore fica como próximo passo.

### Coleções relacionadas
- `tb_limit_app` (escrita: `temaConfig`/cores/fontes), `users` (settings),
  `tb_clinica` (tipo p/ defaults), `tb_plan_user` (plano p/ permissões). ❌ sync remoto pendente.

---

## 2026-06-24 — Mais ajustes de UX

- **Escolher plano** redesenhada (seleção de card + CTA único, plano gratuito
  UBS/UPA/APS, preços BRL, metadados, toggle mensal/anual com selo de economia).
- **Trocar/atualizar plano**: tela `/plano` (assinatura) + modo `?change=true` no
  `/choose-plan`; com plano vinculado, `/choose-plan` redireciona para a home.
- **Arquitetura** (`/arquitetura`): interruptor para habilitar/desabilitar módulos
  (base bloqueada); módulos desligados somem da navegação e têm rota bloqueada.
- **Gráficos**: ícone de IA ao lado de cada gráfico gera relatório de insights.

---

## 2026-06-24 — Sistema de Módulos + Mapa de Dependências

### O que mudou
Implementação do **"🗺️ Mapa de Dependências entre Módulos"** como código (não só
documentação), em `lib/core/modules/`:

- `module.dart` — modelo `AppModule` (id, prioridade, status, `dependsOn`,
  `ownedCollections`, `readsCollections`) + enums `ModulePriority`/`ModuleStatus`.
- `module_registry.dart` — registro único dos 15 módulos com as **arestas exatas**
  do diagrama do AGENTS.md.
- `module_graph.dart` — utilidades de grafo: ordem topológica, detecção de ciclos,
  `dependenciesOf`/`dependentsOf`/`transitiveDependencies` e `validate()`.
- `features/arquitetura/arquitetura_screen.dart` — visualização do mapa (rota
  `/arquitetura`, atalho no drawer "Mapa de Módulos").
- `test/unit/module_graph_test.dart` — valida DAG, ordem topológica, arestas e
  isolamento de coleções.

### Por quê
- O AGENTS.md define explicitamente um mapa de dependências, prioridades e
  **regras de isolamento** ("cada módulo escreve só nas suas coleções; comunicação
  cross-module via `core/services`"). Codificar isso torna as regras **verificáveis**
  (testes falham se alguém criar um ciclo ou dois módulos reivindicarem a mesma
  coleção de escrita), em vez de ficarem só no texto.

### Mapeamento módulo → coleções (isolamento de escrita)
Regra: cada coleção `owned` pertence a **um único** módulo (validado em teste).

| Módulo | Escreve (`owned`) | Lê (compartilhadas) |
|--------|-------------------|---------------------|
| auth | `tb_plan_user`, `tb_users_term` | `users`, `tb_plans`, `tb_limit_app` |
| agendamentos | `tb_agendamentos` | `tb_medicos`, `tb_clinica`, `users` |
| criar_agendamento | `tb_pre_agendamentos` | `tb_hour_agenda`, `tb_hour_atendimento_medico` |
| recepcao | `queue_realoc`, `tb_confirmationHistory` | `tb_agendamentos` |
| absenteismo | `tb_faltas_data`, `dashboard_risco` | `tb_agendamentos`, `tb_medicos` |
| tickets | `tickets` | `users`, `tb_clinica` |
| financeiro | `queues`, `tb_avaliacoes` | `tb_agendamentos`, `tb_plans` |
| prever | `patient_reputation` | `tb_agendamentos`, `dashboard_risco` |
| ia | `tb_relatorio_ia`, `chats`, `chat_history` | `tb_agendamentos`, `tb_faltas_data` |
| integracoes | `email_queue`, `email_logs`, `ff_push_notifications` | `tb_agendamentos` |
| whatsapp | `tb_config_whatsapp`, `tb_conversas` | `tb_agendamentos` |
| perfil_usuario | `users` | — |
| perfil_clinica | `tb_clinica`, `tb_horaios_atendimento` | — |
| home / navegacao | — (somente leitura) | várias |

---

## 2026-06-24 — Planos e vínculo de plano do usuário

### O que mudou
- Modelo `Plan` (`lib/core/models/plan.dart`) refletindo `tb_plans`
  (`nome`, `descricao`, `precoMensal`/`precoAnual`, `recursosInclusos`,
  `isPopular`, `limiteUsuarios`, `limite_consulta`, `nivelSuporte`, `intergracao`).
- `MockData.plans` com 3 planos (Essencial/Profissional/Enterprise).
- Fluxo de **escolha de plano** (`features/auth/choose_plan_screen.dart`) com
  toggle mensal/anual; a seleção é cacheada e, em produção, deve gravar em
  `tb_plan_user` (`id_plan`, `id_user`, `active`, `active_ano`).

### Por quê
- O AGENTS.md exige, após o login, escolher a clínica e então um plano de
  `tb_plans`, registrando o vínculo em `tb_plan_user` e os limites em
  `tb_limit_app`. O modelo e o fluxo de UI já seguem essa estrutura; a escrita
  real no Firestore depende das credenciais/integração ativas.

### Coleções relacionadas (referência `database.md`)
- `tb_plans` — catálogo de planos.
- `tb_plan_user` — plano ativo por usuário (`id_plan`, `id_user`, `active`, `active_ano`).
- `tb_limit_app` — limites por plano (a integrar para enforcement de cotas).

---

## 2026-06-24 — Autenticação via Firebase

### O que mudou
- `FirebaseAuthService` (e-mail/senha + `sendPasswordResetEmail`) com fallback
  `MockAuthService`; `lib/firebase_options.dart` a partir de `.specify/api-key.js`.

### Por quê
- Requisito de ligar o login ao **Firebase Authentication** usando os módulos
  prontos (login, cadastro, recuperação de senha).

### ⚠️ Observação de dados
- Contas do **Firebase Auth** são separadas da coleção `users` do Firestore.
  Para usuários existentes logarem, é necessário importá-los para o Firebase Auth
  (Admin SDK / `firebase auth:import`) — migração de dados pendente.
