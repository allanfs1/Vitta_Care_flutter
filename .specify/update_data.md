# Atualizações — Módulo Totem (Autoatendimento)

> Registro das mudanças implementadas. Foco: tornar o **Totem** um módulo
> independente, totalmente configurável (com prévia ao vivo e perfis),
> integrado à navegação, com envio de e-mail de confirmação, fluxo de
> remarcação por escolha e regras anti-abuso de agendamento.

Data de referência: 2026-06.

---

## 1. Totem como módulo independente da Recepção

**Problema:** o totem dependia do `recepcaoProvider` (contador "X NA FILA") e não
era um módulo ativável em `/arquitetura`.

- `totem_screen.dart`: removido `import recepcao_provider.dart` e o contador
  "NA FILA" do cabeçalho. O totem não consome mais estado da recepção.
- `models/totem_config.dart`: removido o campo `showQueueCounter`.
- `widgets/totem_config_panel.dart`: removido o switch do contador.
- `core/modules/module_registry.dart`: novo `AppModule` **`totem`** (P1,
  implementado), `route: AppRoutes.totem`, `dependsOn: ['agendamentos']`
  (NÃO depende de `recepcao`), `readsCollections: [users, tb_medicos,
  tb_agendamentos]`. Passa a aparecer como card com switch em `/arquitetura`.
- `navigation/app_router.dart`: o guard de redirect agora bloqueia `/totem`
  quando o módulo está desabilitado (antes o early-return `isPublic` ignorava o
  toggle). Quando habilitado, segue **público (sem login)**. Reaproveitada a
  leitura de `disabledModulesProvider`.

## 2. Totem na barra de navegação principal

- `navigation/nav_destinations.dart`: novo `NavItem` "Totem" (ícone `touch_app`,
  rota `/totem`) em `primaryDestinations`.
- O `AppShell` já filtra destinos por módulo habilitado, então o item aparece
  quando o totem está ligado e some quando desligado (reativo).

## 3. Filtro de especialidades "MAIS PROCURADAS"

- `totem_screen.dart`: `_topSpecialties({max})` rankeia especialidades por nº de
  agendamentos ativos (ignora cancelados) e devolve as mais frequentes que
  existem no corpo clínico.
- Nova linha de sugestões "MAIS PROCURADAS" na tela de agendamento, acima da
  lista completa. Helper `_pickSpecialty` (DRY entre os dois grupos de chips).

## 4. Sistema de configuração complexo + página de Configurações

- `features/configuracoes/screens/configuracoes_hub_screen.dart`: novo card
  **"Totem"** que abre o `TotemConfigPanel` (mesmo painel do acesso oculto por
  long-press no logo do totem — fonte única de UI).
- `TotemConfig` expandido com grupos: Marca/Textos, Interface, Sugestões,
  Tela inicial, Agendar/Remarcar, Fluxos, Regras de agendamento, Sessão,
  Funcionamento. Persistido em `SharedPreferences`; `fromJson` tolerante a
  chaves ausentes.

### Campos de configuração (todos conectados ao comportamento)

| Grupo | Campos |
|---|---|
| Marca/Textos | `clinicName`, `welcomeTitle`, `welcomeSubtitle`, `accent`, `logoUrl` |
| Tela inicial | `showTutorial`, `showTestPrint` |
| Interface | `showClock`, `showDoctorCard`, `showOccupancy`, `gradientBackground`, `scale` |
| Sugestões | `showSuggestions`, `maxSuggestions` |
| Agendar/Remarcar | `agendarTitle`, `remarcarTitle`, `agendarButtonLabel`, `remarcarButtonLabel`, `showStepper`, `showWeekStrip`, `showCalendarButton`, `showDoctorFilter` |
| Fluxos | `allowAgendar`, `allowRemarcar`, `allowGuestScheduling`, `requirePhone`, `printEnabled`, `ticketFooter` |
| Regras | `defaultSpecialty`, `appointmentDuration`, `maxDaysAhead`, `arrivalMinutes`, `maxPerDay`, `maxActivePerPatient` |
| Sessão | `sessionTimeout`, `warningSeconds`, `successAutoReturn` |
| Funcionamento | `openHour`, `closeHour`, `openSaturday`, `saturdayCloseHour`, `openSunday`, `lunchBreakEnabled`, `lunchStartHour`, `lunchEndHour` |

## 5. Visualizador em tempo real (prévia)

- `widgets/totem_preview.dart`: `TotemPreview` (ConsumerStateful) observa
  `totemConfigProvider` e atualiza ao vivo conforme a personalização.
- Abas **[Início | Agendar]**:
  - Início: tela de boas-vindas (logo, cor, textos, relógio, fundo, escala,
    botões de fluxo, links de rodapé).
  - Agendar: mock fiel que reflete stepper, título, sugestões (respeitando
    `maxSuggestions`), especialidade, data + calendário, faixa de semana, filtro
    por médico, horários (gerados de `openHour`→`closeHour` pulando almoço) e o
    botão com rótulo configurado.
- Layout responsivo no painel: desktop (≥900px) controles + prévia 400px ao
  lado; mobile prévia fixa no topo (280px) + controles roláveis. `FittedBox`
  sobre design 380×600 evita overflow.

## 6. Logo e configurações de funcionalidades

- `logoUrl`: logo na tela inicial e no comprovante (fallback no coração).
  Helper `_brandLogo` (totem) e `_logo` (prévia) com `loadingBuilder` e
  validação de URL (`http`/`data:`). Campo no painel com **miniatura ao vivo**
  (loading/ok/erro) — explica que imagens sem CORS não carregam na web.
- `showTutorial` / `showTestPrint`: mostram/ocultam os botões do rodapé da home.
- `requirePhone`: exige telefone no cadastro do totem (`_submitNew`).
- `arrivalMinutes`: antecedência no comprovante (oculta a linha quando 0).

## 7. Páginas Agendar/Remarcar personalizáveis

- Título por modo (`agendarTitle` / `remarcarTitle`).
- Rótulo do botão de ação por modo (`agendarButtonLabel` / `remarcarButtonLabel`).
- Liga/desliga de elementos: `showStepper` (Agendar/Confirmar/Sucesso),
  `showWeekStrip`, `showCalendarButton`, `showDoctorFilter`.

## 8. Perfis de configuração (presets + salvar)

- `models/totem_profile.dart`: 5 presets embutidos — **UBS, UPA, APS, Clínica
  Popular, Clínica Normal** — cada um um `TotemConfig` completo por tipo de
  unidade (cores, horários, fluxos, etc.).
- `providers/totem_profiles_provider.dart`: `TotemProfilesNotifier` guarda
  overrides por perfil em `SharedPreferences` (`configFor`, `save`, `restore`,
  `hasOverride`); `activeTotemProfileProvider` (perfil selecionado).
- Painel: seção **PERFIS** no topo com chips (aplicar preset), indicador de
  auto-salvamento e botão **Restaurar** (volta ao preset).
- **Auto-salvamento:** com um perfil selecionado, qualquer alteração grava
  automaticamente no perfil (`_set` chama `save`). Aplicar perfil / "Padrões"
  não criam override sozinhos.

## 9. Cor de destaque exclusiva do totem

- O painel de configuração usa a cor do tema do app (`colorScheme.primary`)
  para sua própria UI (AppBar, seções, switches, sliders). O `accent`
  (`cfg.accentColor`) afeta **somente o totem e a prévia**.

## 10. E-mail de confirmação (Cloud Function)

- `functions/sendConfirmationEmail.js` (registrada em `functions/index.js`):
  envia via SendGrid um e-mail de confirmação/remarcação com template HTML
  (cabeçalho da clínica, dados da consulta, senha, rodapé). Usa o secret
  `SENDGRID_API_KEY`. Deploy: `firebase deploy --only functions:sendConfirmationEmail`.
- `core/services/email_service.dart`: `EmailService.sendConfirmation(...)` chama
  a function (timeout 10s, nunca lança, não bloqueia o fluxo).
  `emailServiceProvider` em `app_providers.dart`.
- `totem_screen.dart`: dispara o e-mail ao **agendar** (`_createAppointment`) e
  **remarcar** (`_doReschedule`), para o e-mail do paciente (cadastro existente
  → `AppUser.email`; novo → campo do formulário), com senha e rodapé.

## 11. Remarcação: escolher qual consulta

- Novo `_Step.chooseAppt` e campo `_reschedOptions`.
- `_searchByCpf` agora guarda **todas** as consultas ativas do paciente:
  - 0 → cria nova (com aviso);
  - 1 → vai direto escolher horário;
  - 2+ → tela **"Qual consulta deseja remarcar?"** (`_chooseApptScreen`),
    listando cada consulta (médico, especialidade, data/hora) em cards.
- `_pickReschedule(appt)` define a escolhida e segue para o novo horário.

## 12. Busca de consultas independente de tempo

- `_searchByCpf`: removido o filtro `start.isAfter(agora − 2h)`. Agora busca
  **todas** as consultas do paciente, qualquer data. Mantém apenas a exclusão de
  **canceladas** e **concluídas** (não remarcáveis).

## 13. Regras anti-abuso de agendamento

- `maxPerDay` (padrão 1, `0 = ilimitado`): máx. de consultas do paciente no
  mesmo dia.
- `maxActivePerPatient` (padrão 3, `0 = ilimitado`): **regra principal** — teto
  de consultas ativas/futuras por paciente (resiste a "espaçar" agendamentos).
- `_activeAppointmentsOf(patientId, name)`: casa por id OU nome (cobre cadastros
  novos do totem). `_bookingLimitMessage(...)` avalia os limites em
  `_createAppointment` (só novos agendamentos; remarcar move, não soma).
- Ao estourar um limite: diálogo **"Limite de agendamentos"** que, se o paciente
  já tem consultas ativas, oferece **"Remarcar existente"** (`_startRescheduleFor`)
  — converte a tentativa de duplicar numa remarcação.
- Preset **UPA**: limites em 0 (urgência não limita).

---

## 14. Verificação geral do totem — correções e melhorias (2026-07-02)

Auditoria completa do módulo (fluxos, config, perfis, prévia) com base também
nos achados registrados em `totem_test.md` (F-1/F-2). Tudo implementado e
validado com `flutter analyze` (0 issues).

**Bugs corrigidos:**
- **F-1 (painel)** — stale closure em `_set`: edições em sequência muito rápida
  podiam reverter o campo anterior. `_set` agora recebe uma função mutadora e
  aplica o `copyWith` sobre o estado **atual** do provider.
- **F-2 (tema)** — cor de destaque aplicada só parcialmente: títulos, botões
  principais (AGENDAR/REMARCAR/CONFIRMAR), tela de CPF, stepper, tutorial,
  banner REMARCANDO, cartão do médico, slots selecionados, overlay de expiração
  e a prévia agora usam `accentColor`; o gradiente do botão inicial deriva do
  accent (antes misturava com o vermelho fixo `0xFFFA4B53`).
- **Tela de sucesso mentia no modo Remarcar sem consulta ativa**: quando o
  paciente entrava por "Remarcar" mas não tinha consulta (cria uma nova), o
  título dizia "Consulta Remarcada!". Nova flag `_wasReschedule` reflete o que
  de fato aconteceu.
- **Convidado em remarcação duplicava a consulta**: no fluxo de remarcar via
  formulário de convidado, `_createAppointment` criava um agendamento novo (e
  esbarrava de novo no limite anti-abuso, em loop). Agora, com remarcação em
  andamento, sempre **move** a consulta existente.
- **Ocupação inflada na remarcação**: a própria consulta sendo remarcada contava
  na ocupação do slot (podia mostrar "LOTADO" à toa). Excluída da contagem.
- **Diálogos órfãos ao expirar a sessão**: tutorial/calendário/diálogo de limite
  ficavam abertos sobre a tela de boas-vindas após o reset por inatividade.
  `_reset` agora fecha qualquer `RawDialogRoute` aberto.
- **Preset UPA "24h" fechava 23h (seg–sex) e 12h (sábado)**: agora 0–24h todos
  os dias; steppers do painel passaram a aceitar abrir às 0h e fechar às 24h
  (antes min 5h/max 23h impediam restaurar o próprio preset).
- **Timer com `setState` duplicado** por tick unificado em um único `setState`.

**Melhorias:**
- **Validação real de CPF** (dígitos verificadores + rejeição de sequências
  repetidas) na busca do Remarcar e na verificação do Agendar — evita consultas
  inúteis ao Firestore e cadastros com CPF de digitação errada. *Obs.: testes
  manuais agora exigem CPFs válidos (ex.: 529.982.247-25).*
- **Validação de e-mail** no cadastro de convidado (formato básico; vazio segue
  permitido) — antes um e-mail com typo silenciosamente não recebia confirmação.
- **PIN de administrador opcional** (`adminPin`, seção SEGURANÇA do painel): o
  totem é rota pública e qualquer paciente podia abrir a configuração com toque
  longo no logo; com PIN definido, o acesso oculto pede o código.

**Sugestões registradas:** todas implementadas em seguida — ver §15.

---

## 15. Sugestões implementadas (2026-07-02)

As 4 sugestões da verificação geral (§14) foram implementadas:

- **Teclado de CPF unificado**: novo widget `_CpfKeypad` (grade 3×4, estados
  desabilitados, cor de destaque) substitui as duas implementações duplicadas
  da busca do Remarcar e do passo de confirmação.
- **Slots na granularidade da consulta**: `_buildSlots` (e a prévia) geram a
  grade no passo de `appointmentDuration` (não mais fixa de hora em hora); o
  slot só entra se a consulta couber antes do fechamento; a ocupação ancora
  cada agendamento no slot que o contém (09:15 → slot 09:00 em grade de 30
  min); filtro de horários passados por minuto.
- **Sincronização via Firestore**: `totemConfigProvider` e
  `totemProfilesProvider` espelham config e overrides de perfil no doc
  `tb_totem_config/{clinicaId}` (campos `config`/`profiles`, `mergeFields`,
  `updatedAt`, snapshot ao vivo). SharedPreferences segue como cache/fallback
  (offline/mock/regras). Requer regra do Firestore liberando leitura para o
  dispositivo do totem (rota pública).
- **Impressão real**: `_printReceipt` gera PDF bobina 80 mm (`pdf` +
  dependência nova `printing`) e abre o diálogo de impressão do
  sistema/navegador; falha vira aviso amigável.

---

## Correções de bugs

| Bug | Correção |
|---|---|
| Intervalo de almoço não refletia na prévia (horários fixos) | Prévia gera horários da config (abre→fecha, pula almoço) |
| Crash no `showDatePicker` quando data > `maxDaysAhead` | `initialDate` fixado em `[hoje, hoje+maxDaysAhead]` |
| Faixa de semana permitia escolher além de `maxDaysAhead` | Dias fora do limite ficam esmaecidos e não clicáveis |
| Almoço com fim ≤ início não bloqueava nada | Steppers acoplados (fim sempre depois do início) |
| "Chegue com 0 minutos" no comprovante | Linha oculta quando `arrivalMinutes = 0` |
| Tela inicial sem botões (Agendar e Remarcar off) | Mensagem "Atendimento indisponível — procure a recepção" |
| Logo não aparecia / parecia não salvar | Era CORS no Flutter Web; adicionados miniatura de status, `loadingBuilder` e validação de URL (o valor sempre é salvo) |

---

## Arquivos tocados (resumo)

**Flutter**
- `lib/features/totem/totem_screen.dart`
- `lib/features/totem/models/totem_config.dart`
- `lib/features/totem/models/totem_profile.dart` (novo)
- `lib/features/totem/providers/totem_config_provider.dart`
- `lib/features/totem/providers/totem_profiles_provider.dart` (novo)
- `lib/features/totem/widgets/totem_config_panel.dart`
- `lib/features/totem/widgets/totem_preview.dart` (novo)
- `lib/core/services/email_service.dart` (novo)
- `lib/core/services/app_providers.dart`
- `lib/core/modules/module_registry.dart`
- `lib/navigation/app_router.dart`
- `lib/navigation/nav_destinations.dart`
- `lib/navigation/app_shell.dart` (já filtrava por módulo)
- `lib/features/configuracoes/screens/configuracoes_hub_screen.dart`

**Cloud Functions**
- `functions/sendConfirmationEmail.js` (novo)
- `functions/index.js`

## Pendências de deploy / operação
- Deploy da function: `firebase deploy --only functions:sendConfirmationEmail`
  (requer secret `SENDGRID_API_KEY`).
- Após mudanças no `TotemConfig` durante o desenvolvimento, use **hot restart**
  (`R`) no `flutter run` — hot reload não basta para mudanças estruturais.
- Logos por URL no Flutter Web exigem CORS na origem da imagem (PNG/JPG; SVG
  não é suportado por `Image.network`).

---

# Confirmação por WhatsApp (Z-API)

- `TotemConfig`: `confirmViaWhatsapp` (toggle, em *Fluxos*) e `confirmationLink`
  (link enviado; padrão a URL da function de confirmação).
- `EmailService.sendWhatsappConfirmation(...)`: posta no `whatsappProxy` (Z-API)
  uma mensagem de confirmação/remarcação com o link; normaliza telefone (DDI 55).
- `totem_screen.dart`: `_sendConfirmations` dispara **e-mail + WhatsApp** (quando
  ativo) ao agendar/remarcar.
- Requer `whatsappProxy` publicado e `tb_config_whatsapp` por clínica.

---

# Assistente de Ajuda (chat + tour guiado com lightbox)

Módulo novo em `lib/features/assistente/`, acessível em qualquer tela por um
botão flutuante **"Ajuda"** (oculto em login/totem/monitor; o tour continua
funcionando nessas telas).

## Arquitetura
- `assistant_models.dart` — `AssistantMessage` (com `tourSuggestions`),
  `HelpAnswer` (FAQ), `HelpStep`, `HelpTour`.
- `assistant_knowledge.dart` — base de conhecimento local (~22 intents),
  `normalizeText` (sem acento), `scoreKeywords` (pontuação; termos curtos casam
  como palavra inteira), `wantsGuidedTour`, perguntas sugeridas.
- `assistant_tours.dart` — 8 tours detalhados (Visão geral, Agenda, Recepção,
  Pacientes, Analytics/IA, Configurar Totem, Uso do Totem, Mapa de Módulos) +
  `HelpAnchors` (ids de spotlight).
- `assistant_anchors.dart` — registro `id→GlobalKey` + `AssistantTarget` +
  `contextOf` (para `ensureVisible`).
- `assistant_controller.dart` — chat **híbrido**: FAQ local primeiro → IA real
  (chatProxy) só quando nada casa; sugere/insere tours como chips; "me guie"
  inicia o tour. Prompt de sistema pede Markdown.
- `assistant_scope.dart` — overlay global dentro de um **`Overlay` próprio**
  (corrige "No Overlay widget found"): FAB, painel de chat (Markdown via
  `flutter_markdown`) e o **spotlight/lightbox**.

## Inteligência (robusta)
- Resposta local instantânea (offline) com pontuação por relevância; IA só para
  perguntas abertas. Corrigido o bug de sempre cair no tour do totem.
- Respostas renderizadas em **Markdown** (negrito, listas, títulos).

## Lightbox / tour
- O passo **navega para a tela**, **rola o alvo para a visão** (`ensureVisible`),
  **tenta localizar o elemento com retry** (até 8x) e o destaca com recorte
  **pulsante** (borda animada + brilho), com balão "Passo X de Y".
- Âncoras reais (`AssistantTarget`): itens do menu (Dashboard, Agenda, Totem,
  Configurações, Mapa de Módulos), cartão **Totem** em Configurações, **FAB de
  novo agendamento** (Agenda), **busca** (Pacientes), **abas** (Recepção) e
  **KPIs** (Dashboard). Passos sem âncora usam balão central.

## IA (Cloud Function)
- `AiService.helpReply(messages)` chama o `chatProxy` (Azure DeepSeek), tentando
  2 hosts (run.app e cloudfunctions.net). A chave fica no servidor — no Flutter
  Web não dá para chamar o Azure direto (CORS).
- Deploy necessário: `firebase functions:secrets:set AZURE_AI_KEY` (valor =
  `AZURE_DEEPSEEK_KEY` do `AI_chaves.md`) + `firebase deploy --only functions:chatProxy`.

## Integração
- `app.dart`: `AssistantScope` envolve o app no `builder` do `MaterialApp.router`.


