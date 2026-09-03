# 🤖 AGENTS TEAMS — Vitta App

> **Projeto:** Vitta App (Flutter)
> **Projeto-todo-em-arquivo-specify:** SPECIFY
> **Tipo:** Aplicação mobile de gestão clínica e agendamentos
> **Público-alvo:** Clínicas privadas, UBS, UPA e APS
> **Stack:** Flutter / Dart
> **Arquitetura:** Feature-first modular (cada módulo em pasta isolada)

---


O projeto deve ser multiplataforma, aplicação deve funcionar em mobile e Computador e ter recursos de WPA para Abrir a aplicaçã em Desktop.
- No mibile visual de aplicativo
_ NA we visual de aplicação para computador.
- UI e UX pegar referencias na pasta Designer

## 📋 Regras de Trabalho dos Agentes 

 # USE AGENTS TEMS
1. Cada agente é responsável por **um módulo isolado** e trabalha de forma **independente e paralela**.
2. Nenhum agente pode modificar arquivos fora do seu módulo, exceto arquivos de rota e navegação (gerenciados pelo Agente Líder).
3. Todos os módulos devem seguir o **Design System** definido na pasta `.specify/Designer/`.
4. Antes de implementar, cada agente deve gerar suas tarefas no arquivo `TASKS.md`.
5. Comunicação entre módulos acontece exclusivamente via **serviços compartilhados** em `lib/core/services/`.


# LOGIN
 Tela de login com recuperação de senah, e cadastro biometrico usando digital salva no computador e cadastro utilizando conta do google.

 # CREATED 
 * Tela para criar uma conta no sistema 

  Criar uma conta no sistema campos email,senha e confirmar a senha
  Criar usando uma conta do google.
---

# Escolher plano
 Depois do login ir para uma tela escolher o nome da clinica e depos mandar para outra tela para escolher um plano em tb_plans (Todos os planos disponiveis para escolher) e tb_plan_user para saber o plano do usuario e tb_limit_app para saber o limite do plano do usuario. se precisar de mais alguns campo adicione. mais depois registre e update_data.md, explicando o porque das modificações.

# AI Utilizados Azure Foundry
  * AI_chaves.mdas

# estrutura Z-PI WhatsApp
 * ZAPI.md

# FIREBASE

 * coleções 
  - Arquivo database.md
  * Credenciasi firebase:
   - api-key.js

## 🏗️ Estrutura de Pastas Esperada

```
lib/
├── main.dart
├── app.dart                          # MaterialApp, rotas, tema global
├── core/
│   ├── theme/                        # Design tokens, cores, tipografia
│   ├── services/                     # Serviços compartilhados (API, Auth, IA)
│   ├── models/                       # Modelos de dados compartilhados
│   ├── widgets/                      # Widgets reutilizáveis globais
│   └── utils/                        # Utilitários e helpers
├── features/
│   ├── home/                         # Módulo: Dashboard Principal
│   ├── agendamentos/                 # Módulo: Agendamentos e Detalhes
│   ├── absenteismo/                  # Módulo: Absenteísmo e Cancelamentos
│   ├── ia/                           # Módulo: Inteligência Artificial
│   ├── perfil_usuario/               # Módulo: Perfil da Conta do Usuário
│   ├── perfil_clinica/               # Módulo: Perfil da Clínica
│   └── whatsapp/                     # Módulo: Integração WhatsApp (Z-API)
└── navigation/
    ├── app_router.dart               # Rotas centralizadas
    └── drawer/                       # Drawer lateral com atalhos
```

---

## 🧑‍💼 Agente 1 — Dashboard Home (`features/home/`)

### Descrição
Tela principal da aplicação, exibida após login. Apresenta uma visão geral consolidada da clínica selecionada.

### Funcionalidades

| ID | Funcionalidade | Detalhes |
|----|----------------|----------|
| H-01 | Seletor de clínica | Dropdown ou modal para selecionar a clínica por ID. Deve persistir a seleção. |
| H-02 | Perfil da unidade | Exibir tipo da unidade: **UBS**, **UPA**, **APS** ou **Clínica Privada**, com visual adaptado a cada perfil. |
| H-03 | Calendário de agendamentos | Visualização mensal/semanal com indicadores coloridos: ✅ Confirmado, ❌ Cancelado, 🕐 Pré-agendado (Agendado). |
| H-04 | Gráficos em tempo real | Gráficos dinâmicos (atualização periódica ou via WebSocket): **Tendência de agendamentos**, **Desempenho da equipe**, **Absenteísmo**, **Taxa de ocupação**, **Tempo médio de espera**. |
| H-05 | KPIs principais | Cards de métricas: **Taxa de Ocupação**, **Taxa de Comparecimento**, **Taxa de Cancelamento**, **Tempo Médio de Espera**, **Tempo Médio de Atendimento**, **Satisfação do Paciente**. |
| H-06 | Barra de atalhos superiores | Navegação rápida para: **Agendamentos**, **Relatórios de IA**, **Pacientes**, **Equipe Médica**. |

### Referência Visual
- `.specify/Designer/screen_home.png`
- `.specify/Designer/Unidade de saude.png`

---

## 📅 Agente 2 — Agendamentos (`features/agendamentos/`)

### Descrição
Módulo completo para visualização e gestão de agendamentos, com detalhamento das consultas.

### Funcionalidades

| ID | Funcionalidade | Detalhes |
|----|----------------|----------|
| A-01 | Lista de agendamentos | Listagem paginada com filtros por data, médico, status e especialidade. |
| A-02 | Detalhamento da consulta | Tela com dados completos: **dados do paciente**, **dados do médico**, **dados da clínica**, **horário**, **status**, **observações**. |
| A-03 | Ações sobre consulta | Botões de ação: ✅ **Confirmar**, ❌ **Cancelar**, 🔄 **Reagendar**. Cada ação deve exigir confirmação via modal. |
| A-04 | Timeline do médico | Visualização da agenda diária do médico em formato timeline vertical. |

### Referência Visual
- `.specify/Designer/pagina_completa_da_cosulta.png`
- `.specify/Designer/agenda_timeline_medico.png`

---

## 📊 Agente 3 — Absenteísmo e Cancelamentos (`features/absenteismo/`)

### Descrição
Módulo analítico dedicado ao monitoramento de faltas, cancelamentos e previsão de risco de absenteísmo.

### Funcionalidades

| ID | Funcionalidade | Detalhes |
|----|----------------|----------|
| AB-01 | Dashboard de absenteísmo | Gráficos consolidados: **pizza**, **barras** e **linha** — exibindo taxas de absenteísmo por período. |
| AB-02 | Dashboard de cancelamentos | Gráficos consolidados: **pizza**, **barras** e **linha** — exibindo taxas de cancelamento por período. |
| AB-03 | Calendário analítico | Calendário com visualização de agendamentos por **mês**, **semana** e **dia**, com código de cores por status. |
| AB-04 | Gráficos de densidade | Mapas de calor (heatmap) indicando horários e dias com maior concentração de faltas. |
| AB-05 | KPIs e métricas-chave | Cards com métricas: **Índice de absenteísmo geral**, **por médico**, **por especialidade**, **por clínica**. |
| AB-06 | Risco de faltas (IA) | Lista de pacientes com **score de risco de falta** calculado por IA, com base no histórico. |
| AB-07 | Relatórios inteligentes | Relatórios analisados por IA com **insights**, **tendências** e **recomendações para tomada de decisão**. |
| AB-08 | Relatório por especialidade | Índice de absenteísmo segmentado por especialidade médica. |
| AB-09 | Relatório por médico | Índice de absenteísmo individual por profissional. |

### Referência Visual
- `.specify/Designer/absenteismo.png`

---

## 🧠 Agente 4 — Inteligência Artificial (`features/ia/`)

### Descrição
Módulo de recursos de IA integrada, com funcionalidades diferenciadas para clínicas privadas (B2B).

### Funcionalidades

| ID | Funcionalidade | Detalhes |
|----|----------------|----------|
| IA-01 | Agendamento inteligente (B2B) | Sistema de agendamento assistido por IA. **Disponível apenas para clínicas privadas.** Sugere horários otimizados com base em histórico e disponibilidade. |
| IA-02 | Análise de dados | IA para análise preditiva e descritiva de dados da clínica (agendamentos, absenteísmo, desempenho). |
| IA-03 | Geração de relatórios | Geração automática de relatórios textuais com insights em linguagem natural. |
| IA-04 | Criação de dashboards | Geração de visualizações de dados personalizadas via prompts do usuário. |
| IA-05 | **Vigia — análise diária** | Ciclo automático que lê a clínica uma vez por dia, publica relatório em `/relatorios` e **propõe** rotinas de prevenção em `/tarefas-agendadas`. Spec completa: [`VIGIA.md`](VIGIA.md). |

### Regras de Negócio
- Funcionalidades B2B (IA-01) devem verificar o tipo da clínica antes de habilitar o recurso.
- Todas as interações com IA devem exibir indicador de carregamento e tratamento de erros.
- **A IA nunca executa automação sozinha.** Rotinas propostas pelo Vigia (IA-05)
  nascem com `status: "suggested"` e só passam a rodar depois de uma pessoa
  aprovar. Ver `VIGIA.md` §2 — são três travas independentes, nenhuma
  dependendo da UI se comportar.
- Escrita da IA no Cérebro é auditada em `tb_cerebro_eventos` com motivo
  obrigatório e nível de confiança.

---

## 👤 Agente 5 — Perfil do Usuário (`features/perfil_usuario/`)

### Descrição
Módulo de gerenciamento do perfil pessoal do usuário autenticado.

### Funcionalidades

| ID | Funcionalidade | Detalhes |
|----|----------------|----------|
| PU-01 | Foto de perfil | Upload e atualização da foto de perfil (câmera ou galeria). |
| PU-02 | Dados pessoais | Edição de: **Nome**, **Sobrenome**, **Data de nascimento**, **Gênero**, **CPF**. |
| PU-03 | Contato | Edição de: **E-mail**, **Telefone**. |
| PU-04 | Endereço | Edição de: **CEP** (com busca automática), **Endereço**, **Número**, **Complemento**, **Bairro**, **Cidade**, **Estado**. |
| PU-05 | Segurança | Alteração de **senha** com validação de senha atual e confirmação. |

### Validações
- CPF: validação de dígitos verificadores.
- E-mail: formato válido.
- CEP: busca automática via API (ex: ViaCEP).
- Senha: mínimo 8 caracteres, incluindo maiúscula, minúscula, número e caractere especial.

---

## 🏥 Agente 6 — Perfil da Clínica (`features/perfil_clinica/`)

### Descrição
Módulo para gestão dos dados cadastrais da unidade de saúde vinculada.

### Funcionalidades

| ID | Funcionalidade | Detalhes |
|----|----------------|----------|
| PC-01 | Dados da clínica | Edição de: **Nome fantasia**, **Razão social**, **CNPJ**, **Tipo** (UBS/UPA/APS/Privada). |
| PC-02 | Endereço da clínica | Edição de endereço completo com busca automática por CEP. |
| PC-03 | Contato da clínica | Edição de: **Telefone**, **E-mail institucional**, **Website**. |
| PC-04 | Logotipo | Upload e atualização do logotipo da clínica. |
| PC-05 | Horário de funcionamento | Configuração dos horários de atendimento por dia da semana. |
| PC-06 | Especialidades | Gestão das especialidades médicas oferecidas pela clínica. |

---

## 💬 Agente 7 — Integração WhatsApp (`features/whatsapp/`)

### Descrição
Módulo para conexão do assistente de WhatsApp da clínica via Z-API, usando pareamento por QR Code.

### Funcionalidades

| ID | Funcionalidade | Detalhes |
|----|----------------|----------|
| WA-01 | Conexão por QR Code | Exibir QR Code gerado pela Z-API para vincular o número de WhatsApp da clínica. |
| WA-02 | Status da conexão | Indicador visual do status: **Conectado**, **Desconectado**, **Reconectando**. |
| WA-03 | Logs de mensagens | Histórico de mensagens enviadas/recebidas pelo assistente automatizado. |
| WA-04 | Configurações do assistente | Mensagens automáticas de confirmação, lembrete e cancelamento. |

### Integração
- API: **Z-API** (https://z-api.io)
- Autenticação via token da instância.

---

## 🧭 Agente 8 — Navegação e Drawer (`navigation/`)

### Descrição
Responsável pela estrutura de navegação global: rotas, drawer lateral e atalhos do sistema.

### Funcionalidades

| ID | Funcionalidade | Detalhes |
|----|----------------|----------|
| NAV-01 | Roteamento | Configuração centralizada de rotas usando `GoRouter` ou `auto_route`. |
| NAV-02 | Drawer lateral | Menu lateral com atalhos para todos os módulos principais. |
| NAV-03 | Bottom Navigation | Barra inferior com navegação para as telas mais acessadas (Home, Agendamentos, IA, Perfil). |
| NAV-04 | Deep linking | Suporte a deep links para acesso direto a agendamentos específicos. |

---

## 🎨 Design System (Compartilhado)

### Referências Visuais
Todas as telas devem seguir os mockups disponíveis em `.specify/Designer/`:

| Arquivo | Descrição |
|---------|-----------|
| `screen_home.png` | Layout da tela principal (Dashboard) |
| `Unidade de saude.png` | Layout do perfil da unidade de saúde |
| `absenteismo.png` | Layout do módulo de absenteísmo |
| `agenda_timeline_medico.png` | Timeline da agenda do médico |
| `pagina_completa_da_cosulta.png` | Detalhamento completo da consulta |
| `area_e_jornada_do_paciente.png` | Área e jornada do paciente |

### Padrões de Design
- **Tema:** Dark mode como padrão, com suporte a light mode.
- **Tipografia:** Google Fonts (Inter ou Poppins).
- **Cores:** Paleta baseada em tons de azul médico (#1E88E5) com acentos em verde saúde (#4CAF50).
- **Componentes:** Cards com bordas arredondadas (12px), sombras sutis, micro-animações em transições.
- **Gráficos:** Usar `fl_chart` ou `syncfusion_flutter_charts`.
- **Ícones:** Material Icons + Cupertino Icons conforme plataforma.

---

## 📦 Dependências Recomendadas

```yaml
dependencies:
  # Navegação
  go_router: ^latest

  # Estado
  flutter_riverpod: ^latest  # ou provider / bloc

  # Gráficos
  fl_chart: ^latest
  syncfusion_flutter_charts: ^latest

  # HTTP / API
  dio: ^latest
  retrofit: ^latest

  # Armazenamento local
  shared_preferences: ^latest
  hive: ^latest

  # Formulários e validação
  flutter_form_builder: ^latest
  form_builder_validators: ^latest

  # Imagens
  image_picker: ^latest
  cached_network_image: ^latest

  # Utilitários
  intl: ^latest
  equatable: ^latest
  json_annotation: ^latest

  # WhatsApp (Z-API)
  # Integração via HTTP (dio) — sem SDK específico

dev_dependencies:
  build_runner: ^latest
  json_serializable: ^latest
  retrofit_generator: ^latest
```

---

## ✅ Próximos Passos

1. Cada agente deve gerar suas tarefas em `TASKS.md`, agrupadas por módulo.
2. Implementar o **Design System** em `lib/core/theme/` antes dos módulos.
3. Configurar a **navegação** (`app_router.dart`) como base para todos os módulos.
4. Iniciar a implementação dos módulos em paralelo, seguindo a ordem de prioridade:
   - 🔴 **Alta:** Home, Agendamentos, Navegação, Recepção
   - 🟡 **Média:** Absenteísmo, Perfil Usuário, Perfil Clínica, Financeiro
   - 🟢 **Baixa:** IA, WhatsApp, Previsão de Faltas, Integrações

---
---

# 📦 MÓDULOS — Especificação Detalhada

> Cada módulo é uma feature isolada em `lib/features/<nome_modulo>/`.
> Todos os módulos comunicam-se via serviços compartilhados em `lib/core/services/`.
> Cada módulo segue a estrutura interna: `screens/`, `widgets/`, `models/`, `providers/`.

---

## 📊 Módulo 1 — Absenteísmo (`features/absenteismo/`)

> **Atualização (2026-07):** AB-09 "Absenteísmo por médico" implementado em
> `absenteismo_screen.dart` com KPIs (índice médio, maior/menor por médico, total
> de faltas) e gráfico de barras por severidade, calculado de dados reais
> (`clinicDoctorsProvider` × `appointmentsProvider`). Ver `update_data.md`.

### Objetivo
Fornecer uma visão analítica completa sobre faltas, cancelamentos e tendências de ausência de pacientes, com suporte a relatórios gerados por IA.

### Estrutura de Pastas

```
features/absenteismo/
├── screens/
│   ├── absenteismo_dashboard_screen.dart
│   ├── cancelamentos_dashboard_screen.dart
│   ├── calendario_analitico_screen.dart
│   ├── densidade_heatmap_screen.dart
│   ├── relatorio_especialidade_screen.dart
│   └── relatorio_medico_screen.dart
├── widgets/
│   ├── kpi_card.dart
│   ├── grafico_pizza.dart
│   ├── grafico_barras.dart
│   ├── grafico_linha.dart
│   ├── heatmap_widget.dart
│   └── paciente_risco_tile.dart
├── models/
│   ├── absenteismo_stats.dart
│   ├── cancelamento_stats.dart
│   └── risco_paciente.dart
└── providers/
    └── absenteismo_provider.dart
```

### Funcionalidades Detalhadas

| ID | Funcionalidade | Descrição | Componente |
|----|----------------|-----------|------------|
| AB-01 | Dashboard de absenteísmo | Gráficos consolidados: **pizza** (proporção faltou/compareceu), **barras** (por mês), **linha** (tendência 12 meses). Filtros: período, clínica, especialidade. | `absenteismo_dashboard_screen.dart` |
| AB-02 | Dashboard de cancelamentos | Mesmos tipos de gráfico, mas segmentados por **motivo de cancelamento** (paciente, clínica, médico, sistema). | `cancelamentos_dashboard_screen.dart` |
| AB-03 | Calendário analítico | Calendário interativo com 3 views (mês/semana/dia). Cada célula mostra total de consultas + código de cores: 🟢 compareceu, 🔴 faltou, 🟡 cancelou, 🔵 reagendou. Tap na célula abre lista de agendamentos. | `calendario_analitico_screen.dart` |
| AB-04 | Gráfico de densidade (heatmap) | Mapa de calor 7×24 (dias da semana × horas do dia) mostrando concentração de faltas. Permite identificar horários críticos. | `densidade_heatmap_screen.dart` |
| AB-05 | KPIs e métricas-chave | Cards no topo: **Índice de absenteísmo geral (%)**, **Taxa de cancelamento (%)**, **Variação vs mês anterior (↑↓)**, **Dia/horário com mais faltas**, **Pacientes com risco alto** (contagem). | `kpi_card.dart` |
| AB-06 | Risco de faltas (score IA) | Lista de pacientes com score de risco calculado pela Cloud Function `scheduledPredictionJob`. Dados vêm de `tb_faltas_data` e `dashboard_risco`. Exibe: nome, score (0-100), label de risco (alto/médio/baixo), prioridade, cor de alerta. Permite ordenar por score decrescente. | `paciente_risco_tile.dart` |
| AB-07 | Relatórios inteligentes IA | Tela que exibe relatórios da coleção `tb_relatorio_ia`. Campos exibidos: `resumoExecutivo`, `totalAgendamentos`, `taxaFaltas`, `sugestoes[]`, `fatoresRisco[]`, `pacientesRiscoAlto`. Filtro por `tipoRelatorio` e `periodoInicio/Fim`. Botão "Gerar novo relatório" chama API de IA (Azure DeepSeek). | `relatorio_ia_screen.dart` |
| AB-08 | Relatório por especialidade | Tabela agrupada por especialidade com colunas: **Especialidade**, **Total consultas**, **Faltas**, **Índice (%)**, **Tendência**. Dados de `tb_agendamentos` agrupados por campo `especialidade`. | `relatorio_especialidade_screen.dart` |
| AB-09 | Relatório por médico | Tabela agrupada por médico com colunas: **Médico**, **CRM**, **Total consultas**, **Faltas**, **Índice (%)**, **Ranking**. Dados cruzados de `tb_agendamentos` + `tb_medicos`. | `relatorio_medico_screen.dart` |

### Coleções Firestore Utilizadas
- `tb_agendamentos` — fonte primária (campo `status` para identificar faltas/cancelamentos)
- `tb_faltas_data` — dados de previsão de risco (`valor_predicao`, `probabilidade_falta`, `risco_falta`)
- `dashboard_risco` — scores de risco consolidados
- `tb_relatorio_ia` — relatórios gerados por IA
- `patient_reputation` — reputação do paciente (`score`, `level`, `trend`, `totalNoShows`)
- `tb_medicos` — dados dos médicos (nome, especialidades, estatísticas)

### Referência Visual
- `.specify/Designer/absenteismo.png`

---

## 📅 Módulo 2 — Criar Agendamento (`features/agendamentos/criar/`)

### Objetivo
Fluxo completo para criação de um novo agendamento, com validações de disponibilidade, overbooking, e notificação automática.

### Estrutura de Pastas

```
features/agendamentos/criar/
├── screens/
│   ├── selecionar_paciente_screen.dart
│   ├── selecionar_medico_screen.dart
│   ├── selecionar_horario_screen.dart
│   ├── dados_consulta_screen.dart
│   └── confirmacao_agendamento_screen.dart
├── widgets/
│   ├── paciente_search_bar.dart
│   ├── medico_card.dart
│   ├── slot_horario_chip.dart
│   └── resumo_agendamento_card.dart
├── models/
│   ├── novo_agendamento.dart
│   └── slot_disponivel.dart
└── providers/
    └── criar_agendamento_provider.dart
```

### Fluxo do Usuário (Stepper)

| Etapa | Tela | Descrição |
|-------|------|-----------|
| 1 | Selecionar paciente | Busca por nome, CPF ou telefone. Se não encontrado, botão "Cadastrar novo paciente" (inline). Dados de `users` e `tb_pre_agendamentos`. |
| 2 | Selecionar médico | Lista de médicos da clínica com filtro por especialidade. Card mostra: foto, nome, CRM, especialidades, status (online/offline). Dados de `tb_medicos`. |
| 3 | Selecionar horário | Calendário + lista de slots disponíveis do médico. Slots vêm de `tb_hour_agenda`. Slots ocupados ficam desabilitados. Respeita `horarioFuncionamento` e `limitesSeguranca.maxPacientesPorHorario` do médico. Indica quando há **overbooking** ativo (badge amarelo). |
| 4 | Dados da consulta | Formulário: **Tipo de consulta** (retorno, primeira vez, urgência), **Modalidade** (presencial, teleconsulta), **Especialidade**, **Motivo da consulta**, **Forma de pagamento** (particular, convênio), **Observações**. |
| 5 | Confirmação | Resumo completo do agendamento. Botão "Confirmar e criar". Ao confirmar, chama Cloud Function `registrarAgendamentoOficial`. |

### Regras de Negócio
- **Overbooking:** Se o slot está no limite, verificar `maxOverbook` do médico + `overbookingConfig` do dia da semana. Se permitido, criar com flag visual de overbooking.
- **Ticket:** Gerar número de ticket automático sequencial por clínica (campo `ticket` em `tb_agendamentos`).
- **Pré-agendamento:** Se o paciente veio de um pré-agendamento (coleção `tb_pre_agendamentos`), vincular o ID e atualizar status para "convertido".
- **Notificações:** Após criação, disparar confirmação via:
  - E-mail (Cloud Function `sendConfirmAppointmentEmail`)
  - Push notification (via `ff_push_notifications`)
  - WhatsApp (se Z-API configurada, via `tb_config_whatsapp`)
- **Validações:** Não permitir dois agendamentos do mesmo paciente no mesmo horário. Verificar `tb_limit_app.tl_consultas` do plano.

### Coleções Firestore Utilizadas
- `tb_agendamentos` — escrita (criar documento)
- `tb_pre_agendamentos` — leitura (verificar pré-agendamentos existentes)
- `tb_medicos` — leitura (dados do médico, horários, overbooking config)
- `tb_hour_agenda` — leitura (slots disponíveis)
- `users` — leitura (dados do paciente)
- `tb_clinica` — leitura (dados da clínica)
- `tb_limit_app` — leitura (verificar limites do plano)
- `tb_config_whatsapp` — leitura (verificar se WhatsApp está ativo)

### Cloud Functions Envolvidas
- `registrarAgendamentoOficial` — cria o agendamento oficial
- `onAgendamentoCreate` — trigger após criação (envia confirmações)
- `sendConfirmAppointmentEmail` — e-mail de confirmação

---

## 💰 Módulo 3 — Financeiro (`features/financeiro/`)

### Objetivo
Módulo para gestão financeira da clínica: controle de receitas, serviços prestados, e métricas financeiras. Inclui fila de atendimento financeiro.

### Estrutura de Pastas

```
features/financeiro/
├── screens/
│   ├── financeiro_dashboard_screen.dart
│   ├── servicos_list_screen.dart
│   ├── servico_form_screen.dart
│   ├── receita_por_periodo_screen.dart
│   └── fila_financeiro_screen.dart
├── widgets/
│   ├── receita_kpi_card.dart
│   ├── servico_tile.dart
│   ├── grafico_receita.dart
│   └── fila_ticket_card.dart
├── models/
│   ├── servico.dart
│   ├── receita_resumo.dart
│   └── fila_item.dart
└── providers/
    └── financeiro_provider.dart
```

### Funcionalidades Detalhadas

| ID | Funcionalidade | Descrição |
|----|----------------|-----------|
| FIN-01 | Dashboard financeiro | KPIs: **Receita do mês**, **Receita do dia**, **Ticket médio**, **Total de serviços prestados**, **Receita por especialidade**. Gráficos de barras (receita/mês) e pizza (receita por forma de pagamento). |
| FIN-02 | Cadastro de serviços | CRUD da coleção `tb_service`: **Título**, **Descrição**, **Preço**, **Recorrente (sim/não)**. Vinculado a `idclinica`. |
| FIN-03 | Receita por período | Relatório com filtros por data (início/fim), médico e especialidade. Calcula receita baseada em `tb_agendamentos` (consultas com status "atendido") × preço do serviço/ticket do médico. |
| FIN-04 | Fila de atendimento financeiro | Visualização da fila `queue_financeiro` (coleção `queues`). Mostra tickets da coleção `tickets` atribuídos a esta fila. Status: aberto, em atendimento, resolvido. SLA configurável. |
| FIN-05 | Formas de pagamento | Análise por forma de pagamento (campo `formaPagamento` de `tb_agendamentos`): particular, convênio, SUS. Gráfico de distribuição. |

### Coleções Firestore Utilizadas
- `tb_service` — CRUD de serviços (`titulo`, `preco`, `recorrente`, `idclinica`)
- `tb_agendamentos` — leitura (campo `formaPagamento`, `status`, cruzar com tickets de médicos)
- `tb_medicos` — leitura (campo `tiket` = valor do ticket do médico)
- `queues` — leitura (fila `queue_financeiro`, config de SLA e capacidade)
- `tickets` — leitura/escrita (tickets atribuídos à fila financeiro)
- `tb_clinica` — leitura (dados da clínica)

---

## 🧠 Módulo 4 — Modo AI / Agente de Inteligência Artificial (`features/ia/`)

### Objetivo
Hub de IA centralizado com chat interativo, geração de relatórios, análise preditiva e agendamento inteligente (B2B).

### Estrutura de Pastas

```
features/ia/
├── ia_screen.dart                  # hub /ia — 3 colunas responsivas
├── agent/
│   ├── ai_agent_service.dart       # loop de ferramentas (6 rodadas) + planner
│   ├── agent_controller.dart       # estado do chat
│   ├── agent_models.dart           # ChatMessage, PlanTask
│   ├── agent_orchestrator.dart     # modo Agentes (execução paralela)
│   ├── agent_plans_service.dart    # tb_agent_plans
│   ├── ia_chats_service.dart       # tb_ia_chats (histórico)
│   ├── ia_alerts_provider.dart     # alertas proativos (poll 60 s)
│   ├── ia_suggestions.dart         # autocomplete por categoria
│   ├── ia_session.dart             # estado da sessão / sidebars
│   ├── chat_interface.dart
│   ├── document_service.dart       # anexos → Cloud Function analyzeDocument
│   ├── voice_input_service.dart    # STT pt_BR (speech_to_text)
│   └── ai_export_service.dart      # exportar conversa / plano
├── vigia/                          # ciclo diário — ver VIGIA.md
│   ├── vigia_service.dart
│   ├── vigia_prompt.dart
│   ├── vigia_models.dart
│   └── vigia_providers.dart
└── widgets/                        # 14 widgets da /ia
    ├── ai_dashboard_left_sidebar.dart
    ├── ai_dashboard_main_area.dart
    ├── ai_dashboard_right_sidebar.dart
    ├── ai_chat_panel.dart · ai_chat_sheet.dart
    ├── ai_agents_panel.dart · saved_plans_panel.dart
    ├── ai_chart_view.dart          # blocos json-chart → gráficos
    ├── ai_rich_content.dart · ai_report_card.dart
    ├── ia_suggestions_panel.dart
    ├── smart_scheduling_card.dart  # IA-06 (B2B)
    ├── attachment_button.dart · voice_mic_button.dart
```

> ⚠️ **Corrigido em 2026-09-01.** Esta seção descrevia uma estrutura
> (`screens/ia_hub_screen.dart`, `models/`, `providers/ia_provider.dart`,
> `services/azure_deepseek_service.dart`) que **nunca existiu no código**. As
> ferramentas do agente não ficam aqui — vivem em `lib/core/modules/mcp/`
> (ver [`MCP.md`](MCP.md)).

### Funcionalidades Detalhadas

| ID | Funcionalidade | Descrição |
|----|----------------|-----------|
| IA-01 | Hub de IA | Tela central com cards de acesso rápido: "Chat com IA", "Gerar Relatório", "Criar Dashboard", "Agendamento Inteligente" (B2B only). |
| IA-02 | Chat com IA | Interface de chat conversacional usando DeepSeek v4 (Azure Foundry). Histórico salvo em `chats`. Suporta contexto da clínica (dados de agendamentos, métricas, KPIs). Permite anexar arquivos (campo `messages[].files[]`). |
| IA-03 | Análise de dados | IA analisa dados de `tb_agendamentos`, `tb_faltas_data`, `patient_reputation` e gera insights: tendências, padrões de cancelamento, desempenho por médico. Resultado exibido como relatório formatado. |
| IA-04 | Geração de relatórios | Gera relatórios textuais salvos em `tb_relatorio_ia`. Tipos: operacional, mensal, preditivo. Campos: `resumoExecutivo`, `sugestoes[]`, `fatoresRisco[]`. Exportar como PDF. |
| IA-05 | Criação de dashboards | Usuário descreve via prompt o que quer visualizar. IA gera especificação de gráfico (tipo, dados, filtros). App renderiza o gráfico dinamicamente usando `fl_chart`. |
| IA-06 | Agendamento inteligente (B2B) | **Disponível apenas para clínicas privadas** (`tb_clinica.tipo == 'privada'`). IA sugere horários otimizados baseado em: histórico de comparecimento do paciente, ocupação do médico, horários com menor absenteísmo (heatmap). Usa dados de `tb_historico`, `dashboard_risco`, `tb_hour_agenda`. |

### Integração com Azure Foundry (DeepSeek)

Centralizada em `lib/core/services/ai_config.dart` — **não** num
`azure_deepseek_service.dart` (esse arquivo não existe).

```dart
// lib/core/services/ai_config.dart
// Produção:  --dart-define=AI_PROXY_URL=<url da Cloud Function chatProxy>
//            → a credencial fica no servidor, nunca no bundle.
// Dev:       --dart-define=AZURE_AI_KEY=<chave>  (acesso direto)
//
// Endpoint direto (AI Foundry):
//   https://micro-mrfgtgfz-eastus2.services.ai.azure.com/models/chat/completions
//     ?api-version=2024-05-01-preview
// Modelos: DeepSeek-V4-Flash (padrão) · DeepSeek-V4-Pro
// Formato: OpenAI-compatible (chat/completions, com tools/tool_calls)
```

> ⚠️ **Corrigido em 2026-09-01.** O endpoint documentado aqui era
> `micro-mpfiisv0-eastus2.services.ai.azure.com/openai/v1/`, que mistura o nome
> do recurso de **Document Intelligence** (`micro-mpfiisv0`) com o domínio do
> **AI Foundry** — não resolve. Os dois recursos são distintos e têm chaves
> distintas. Ver [`AI_chaves.md`](AI_chaves.md) §3.

### Regras de Negócio

| Regra | Estado |
|---|---|
| **Isolamento multi-tenant:** toda ferramenta opera na clínica de `clinicaResolvidaProvider`; sem clínica resolvida, **nenhuma tool executa** | ✅ `MCP.md` §3.1 |
| **A IA nunca liga uma automação sozinha:** rotinas propostas nascem `suggested` e exigem aprovação humana | ✅ `VIGIA.md` §2 |
| **B2B check (IA-06):** o agendamento inteligente só habilita para clínica **privada**; os demais tipos veem o recurso *bloqueado*, não escondido | ✅ `smart_scheduling_card.dart` |
| **Loading:** toda interação de IA mostra progresso — chips de ferramenta piscando + streaming do texto | ✅ |
| **Fallback:** falha de API vira mensagem amigável; 429/503 têm retry com backoff que respeita `Retry-After` | ✅ `ai_agent_service.dart` |
| **Rate limiting (30 req/min por clínica)** | ❌ **não implementado** — nem no app, nem na `chatProxy` |
| **Contexto de 30 dias no system prompt** | 🟡 o system prompt carrega o `clinicaId`; o resumo da clínica não é pré-injetado — o agente busca via ferramentas |

> ⚠️ Corrigido em 2026-09-01: a versão anterior afirmava que o B2B era checado
> por `tb_plan_user` → `tb_plans.intergracao == true` (o gate real é o tipo da
> clínica) e listava rate limiting como regra vigente, quando não existe código
> que a aplique.

### Coleções Firestore Utilizadas

| Coleção | Uso |
|---|---|
| `tb_ia_chats` | CRUD — histórico de conversas |
| `tb_agent_plans` | CRUD — planos do modo Agentes |
| `tb_relatorio_ia` | escrita — relatórios gerados |
| `tb_scheduled_tasks` | CRUD — rotinas (inclui as propostas pela IA) |
| `tb_vigia_ciclos` | escrita — auditoria do ciclo diário |
| `tb_cerebro_notas` / `tb_cerebro_eventos` | CRUD — memória do agente + auditoria |
| `tb_agendamentos` | leitura — dados para análise |
| `tb_faltas_data` · `dashboard_risco` | leitura — dados preditivos e scores |
| `patient_reputation` | leitura — reputação do paciente |
| `email_queue` / `email_logs` | escrita/leitura — fila e log de e-mail |

> ⚠️ A coleção do histórico é **`tb_ia_chats`**, não `chats`. `ModuleRegistry`
> (`module_registry.dart:279`) ainda declara `['tb_relatorio_ia', 'chats',
> 'chat_history']` — duas coleções que o código não usa, e sem citar
> `tb_ia_chats` nem `tb_agent_plans`. Corrigir o registry é item de dívida
> técnica em [`ATENCAO.md`](ATENCAO.md).

---

## 🏢 Módulo 5 — Modo Recepção (`features/recepcao/`)

### Objetivo
Ponto de acesso rápido para redirecionar o usuário à **plataforma externa de recepção** (sistema web legado/dedicado). Este módulo **não possui funcionalidades internas** — serve apenas como atalho de navegação.

### Estrutura de Pastas

```
features/recepcao/
└── screens/
    └── recepcao_redirect_screen.dart
```

### Funcionalidades

| ID | Funcionalidade | Descrição |
|----|----------------|-----------|
| REC-01 | Botão de redirecionamento | Botão centralizado com ícone e texto "Abrir Recepção" que abre a plataforma externa de recepção em uma nova aba (web) ou no navegador do dispositivo (mobile) via `url_launcher`. |

### Comportamento
- **Web/Desktop:** Abre a URL da plataforma de recepção em nova aba (`launchUrl` com `webOnlyWindowName: '_blank'`).
- **Mobile:** Abre no navegador padrão do dispositivo.
- **URL:** Configurável por clínica (pode ser salva em `tb_clinica` ou em um campo de configuração).
- **Visual:** Tela simples com logo da plataforma, descrição curta ("Acesse o sistema de recepção da clínica") e botão grande de ação.

### Permissões
- Acessível para usuários com `roles` contendo "recepcionista" ou "admin".


---

## 🎫 Módulo 6 — Modo Atendimento ao Paciente / Tickets (`features/tickets/`)

### Objetivo
Sistema de tickets para atendimento ao paciente, com fila organizada, SLA, prioridades e timeline de ações. Suporte multicanal (presencial, WhatsApp, e-mail).

### Estrutura de Pastas

```
features/tickets/
├── screens/
│   ├── tickets_dashboard_screen.dart
│   ├── ticket_detalhe_screen.dart
│   ├── criar_ticket_screen.dart
│   └── filas_config_screen.dart
├── widgets/
│   ├── ticket_card.dart
│   ├── ticket_timeline_widget.dart
│   ├── sla_indicator.dart
│   ├── prioridade_badge.dart
│   └── fila_stats_card.dart
├── models/
│   ├── ticket.dart
│   ├── fila.dart
│   └── timeline_event.dart
└── providers/
    └── tickets_provider.dart
```

### Funcionalidades Detalhadas

| ID | Funcionalidade | Descrição |
|----|----------------|-----------|
| TK-01 | Dashboard de tickets | KPIs: **Tickets abertos**, **Em atendimento**, **Resolvidos hoje**, **Tempo médio de resposta**, **SLA cumprido (%)**. Gráfico de tickets por status e por fila. |
| TK-02 | Criar ticket | Formulário: **Origem** (presencial, WhatsApp, e-mail, telefone), **Assunto**, **Prioridade** (baixa, média, alta, urgente), **Fila** (selecionar entre filas disponíveis em `queues`), **Dados do paciente** (nome, e-mail, telefone). Gera protocolo automático (campo `protocol`). |
| TK-03 | Detalhes do ticket | Tela com dados completos: protocolo, origem, assunto, prioridade, status, fila atribuída, agente atribuído (`assignedTo`). **Timeline** de ações com histórico completo (`timeline[].action`, `timestamp`, `details`). Tags editáveis. |
| TK-04 | Ações sobre ticket | Botões: 📋 **Atribuir a mim**, ▶️ **Iniciar atendimento**, ✅ **Resolver**, 🔄 **Transferir para outra fila**, ⏫ **Escalar prioridade**. Cada ação adiciona entrada na `timeline[]`. |
| TK-05 | Gestão de filas | Configuração das filas (`queues`): nome, estratégia de distribuição (`distributionStrategy`), SLA (`firstResponse`, `resolution`), capacidade máxima (`maxQueueSize`, `maxConcurrentChats`), tags, prioridade. |
| TK-06 | Indicador de SLA | Barra visual de SLA em cada ticket: 🟢 dentro do prazo, 🟡 próximo do limite, 🔴 SLA violado. Calcula baseado em `timestamps.created` vs `sla.firstResponse` e `sla.resolution`. |

### Coleções Firestore Utilizadas
- `tickets` — CRUD (protocolo, fila, status, timeline, prioridade, agente atribuído)
- `queues` — leitura/escrita (configuração de filas, SLA, capacidade)
- `agents` — leitura (agentes disponíveis para atribuição, métricas)
- `users` — leitura (dados do paciente vinculado ao ticket)

### Cloud Functions Envolvidas
- `sendGenericEmail` / `sendGenericEmailADM` — notificar paciente sobre status do ticket

---

## 🔮 Módulo 7 — Modo para Prever Faltas (`features/previsao_faltas/`)

### Objetivo
Módulo preditivo que utiliza machine learning (via Cloud Functions + Azure IA) para calcular a probabilidade de falta de cada paciente, permitindo ações preventivas.

### Estrutura de Pastas

```
features/previsao_faltas/
├── screens/
│   ├── previsao_dashboard_screen.dart
│   ├── paciente_risco_detalhe_screen.dart
│   ├── acoes_preventivas_screen.dart
│   └── historico_predicoes_screen.dart
├── widgets/
│   ├── risco_gauge_chart.dart
│   ├── paciente_risco_card.dart
│   ├── fator_risco_chip.dart
│   ├── acao_preventiva_tile.dart
│   └── predicao_timeline.dart
├── models/
│   ├── predicao_falta.dart
│   ├── fator_risco.dart
│   └── acao_preventiva.dart
└── providers/
    └── previsao_faltas_provider.dart
```

### Funcionalidades Detalhadas

| ID | Funcionalidade | Descrição |
|----|----------------|-----------|
| PF-01 | Dashboard de previsões | Visão geral: **Total de pacientes analisados**, **Alto risco (>70%)**, **Médio risco (40-70%)**, **Baixo risco (<40%)**. Gráfico de distribuição de risco. Lista dos top 20 pacientes com maior risco para a próxima semana. |
| PF-02 | Detalhe do paciente (risco) | Tela individual: **Gauge chart** com probabilidade de falta (0-100%), **Label de risco** (alto/médio/baixo), **Fatores contribuintes** (chips: distância, histórico de faltas, dia da semana, horário, tipo de consulta, plano de saúde, primeira consulta, faixa etária). Dados de `tb_historico` + `tb_faltas_data`. |
| PF-03 | Ações preventivas | Para cada paciente de alto risco, sugerir ações: 📱 **Enviar lembrete extra** (WhatsApp/Push/E-mail), 🔄 **Sugerir reagendamento** para horário com menor taxa de falta, 📞 **Ligar para confirmar**, 🎫 **Oferecer teleconsulta**. Ao executar ação, registra em `tb_lembrete_controle`. |
| PF-04 | Lembrete proativo | Configurar envio automático de lembretes baseado no nível de risco: **Alto risco** → lembrete 72h + 24h + 2h antes; **Médio risco** → lembrete 24h antes; **Baixo risco** → lembrete padrão. Usa `sendDailyReminders` e `ffRemindersCronPush`. |
| PF-05 | Histórico de predições | Tabela com todas as predições geradas pela Cloud Function `scheduledPredictionJob`. Colunas: data da predição, paciente, consulta, probabilidade, risco, se compareceu (resultado real). Permite avaliar acurácia do modelo. |
| PF-06 | Reputação do paciente | Visualização da coleção `patient_reputation`: **Score** (0-100), **Nível** (confiável, regular, crítico), **Tendência** (melhorando, estável, piorando), **Total de consultas**, **Total de no-shows**, **Histórico** de mudanças de score. |

### Variáveis do Modelo Preditivo (de `tb_historico`)
| Variável | Tipo | Descrição |
|----------|------|-----------|
| `faixa_etaria` | categórica | Faixa etária do paciente |
| `sexo` | categórica | Sexo do paciente |
| `dia_semana` | categórica | Dia da semana da consulta |
| `historico_faltas` | categórica | Frequência de faltas anteriores |
| `primeira_consulta` | booleana | Se é a primeira consulta |
| `confirmado` | booleana | Se confirmou presença |
| `recebeu_lembrete` | booleana | Se recebeu lembrete |
| `meio_lembrete` | categórica | Canal do lembrete (WhatsApp, e-mail, SMS) |
| `tempo_espera` | numérica | Tempo médio de espera em consultas anteriores (min) |
| `distancia_clinica_km` | numérica | Distância até a clínica (km) |
| `dias_antecedencia` | numérica | Quantos dias antes foi agendado |
| `canal_agendamento` | categórica | Canal de agendamento (WhatsApp, web, recepção) |
| `plano_saude` | categórica | Tipo de plano (SUS, convênio, particular) |
| `presenca_ultimas_consultas` | array numérico | Binário [1,1,0,1] das últimas consultas |

### Coleções Firestore Utilizadas
- `tb_faltas_data` — leitura (predições: `probabilidade_falta`, `risco_falta`, `valor_predicao`)
- `tb_historico` — leitura (variáveis comportamentais do paciente)
- `dashboard_risco` — leitura (scores consolidados: `riscoPercent`, `riscoLabel`, `prioridade`)
- `patient_reputation` — leitura (reputação: `score`, `level`, `trend`, `totalNoShows`)
- `tb_lembrete` — leitura/escrita (lembretes agendados)
- `tb_lembrete_controle` — leitura/escrita (controle de envios: `totalEnviado`, `ultimoStatus`)
- `tb_agendamentos` — leitura (verificar resultado real: compareceu ou não)

### Cloud Functions Envolvidas
- `scheduledPredictionJob` — gera predições em batch (scheduled)
- `checkFaltasPacientes` — verifica faltas dos pacientes
- `sendDailyReminders` — envia lembretes diários
- `ffRemindersCronPush` — push notifications de lembretes
- `ffEnqueueHighRiskPatients` — enfileira pacientes de alto risco para notificação
- `confirmarPacientesIA` — confirmação automatizada via IA

---

## 🔗 Módulo 8 — Integrações (`features/integracoes/`)

### Objetivo
Central de integrações externas: Google Calendar, WhatsApp (Z-API), e-mail SMTP, push notifications. O usuário pode ativar/desativar e configurar cada integração.

### Estrutura de Pastas

```
features/integracoes/
├── screens/
│   ├── integracoes_hub_screen.dart
│   ├── google_calendar_screen.dart
│   ├── whatsapp_config_screen.dart
│   ├── email_config_screen.dart
│   └── push_config_screen.dart
├── widgets/
│   ├── integracao_card.dart
│   ├── status_conexao_badge.dart
│   ├── qr_code_widget.dart
│   └── sync_status_timeline.dart
├── models/
│   ├── integracao.dart
│   ├── google_calendar_config.dart
│   └── whatsapp_config.dart
└── providers/
    └── integracoes_provider.dart
```

### Funcionalidades Detalhadas

| ID | Funcionalidade | Descrição |
|----|----------------|-----------|
| INT-01 | Hub de integrações | Grid de cards de integrações disponíveis. Cada card mostra: ícone, nome, descrição, status (ativo/inativo/erro), botão "Configurar". |
| INT-02 | Google Calendar | Sincronização bidirecional de agendamentos com Google Calendar. **OAuth 2.0** via Cloud Functions `gcalOAuthStart` → `gcalOAuthCallback`. Status de sincronização por agendamento: campo `calendarSyncStatus` em `tb_agendamentos` ("synced", "pending", "error"). Exibe erros de sincronização (`calendarSyncError`). Botão "Reconectar" e "Desconectar". |
| INT-03 | WhatsApp (Z-API) | Configuração da integração Z-API. **Conexão por QR Code** via Cloud Function `getZapiQRCode`. Campos configuráveis de `tb_config_whatsapp`: `tokenCliente`, `intanceId`, `token`. Status de conexão: ativo/inativo (campo `active`). Configuração de mensagens automáticas em `tb_configuracao_chat`: mensagens de confirmação, lembrete, cancelamento. Visualização do chatbot config (médicos vinculados, especialidades, horários). |
| INT-04 | E-mail (SMTP) | Configuração do serviço de e-mail. Logs de e-mails enviados (`email_logs`): appointmentId, tipo, data. Fila de e-mails pendentes (`email_queue`): status, tentativas, erros. Dashboard: total enviados, falhas, taxa de sucesso. Cloud Functions: `enqueueEmails`, `ffProcessEmailQueue`. |
| INT-05 | Push Notifications | Configuração de notificações push. Visualização de métricas (`push_metrics`). Logs de notificações enviadas (`ff_push_notifications`). Configuração por evento: confirmar consulta, lembrete, cancelamento, overbooking. Token FCM do usuário gerenciado via `addFcmToken` / `ffSaveFcmToken`. |
| INT-06 | Status geral de integrações | Painel unificado mostrando saúde de todas as integrações: último sync, erros recentes, uso do mês (e-mails enviados, mensagens WhatsApp, syncs do Calendar). |

### Coleções Firestore Utilizadas
- `tb_config_whatsapp` — CRUD (configuração Z-API por clínica)
- `tb_configuracao_chat` — leitura/escrita (config do chatbot: médicos, especialidades, agenda)
- `tb_agendamentos` — leitura (campos `calendarSyncStatus`, `calendarSyncError`)
- `email_logs` — leitura (histórico de e-mails)
- `email_queue` — leitura (fila de envio)
- `ff_push_notifications` — leitura (notificações push enviadas)
- `push_metrics` — leitura (métricas de push)
- `tb_conversas` — leitura (conversas WhatsApp)
- `session_chat` — leitura (sessões ativas do chatbot)

### Cloud Functions Envolvidas
- `gcalOAuthStart` / `gcalOAuthCallback` — fluxo OAuth do Google Calendar
- `getZapiQRCode` — gerar QR Code da Z-API
- `testWhatsApp` / `testWhatsAppBatch` — testar envio de mensagens
- `enqueueEmails` / `ffProcessEmailQueue` — fila de e-mails
- `addFcmToken` / `ffSaveFcmToken` — gerenciar tokens FCM
- `sendPushNotificationsTrigger` — trigger de envio de push

---

## 🗺️ Mapa de Dependências entre Módulos

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐
│   Auth (9)  │────▶│   Home (1)   │────▶│  Agendamentos(2) │
└─────────────┘     └──────────────┘     └──────────────────┘
                           │                      │
                           ▼                      ▼
                    ┌──────────────┐     ┌──────────────────┐
                    │ Recepção (5) │     │ Criar Agend. (2) │
                    └──────────────┘     └──────────────────┘
                           │                      │
                    ┌──────┴──────┐         ┌─────┴──────┐
                    ▼             ▼         ▼            ▼
              ┌──────────┐ ┌──────────┐ ┌────────┐ ┌──────────┐
              │Tickets(6)│ │Prever(7) │ │IA (4)  │ │Financ.(3)│
              └──────────┘ └──────────┘ └────────┘ └──────────┘
                                              │
                                              ▼
                                     ┌──────────────────┐
                                     │ Integrações (8)  │
                                     └──────────────────┘
```

### Regras de Isolamento
- Cada módulo **lê** de coleções compartilhadas mas **escreve** apenas nas suas coleções dedicadas.
- Comunicação cross-module acontece via `lib/core/services/` (ex: `AgendamentoService`, `ClinicaService`, `AuthService`).
- Nenhum módulo importa diretamente de outro `features/` — sempre via `core/`.

---

## 📋 Ordem de Implementação por Prioridade

| Prioridade | Módulo | Justificativa |
|------------|--------|---------------|
| 🔴 P0 | Auth (9), Navegação (8), Home (1) | Base do app — sem isso nada funciona |
| 🔴 P0 | Agendamentos (2) + Criar Agendamento | Core business |
| 🔴 P1 | Recepção (5) | Fluxo diário da clínica |
| 🟡 P2 | Absenteísmo (1) | Analytics essencial |
| 🟡 P2 | Tickets (6) | Atendimento ao paciente |
| 🟡 P2 | Financeiro (3) | Controle de receitas |
| 🟢 P3 | Previsão de Faltas (7) | Depende de dados existentes |
| 🟢 P3 | Modo AI (4) | Depende de integração Azure |
| 🟢 P3 | Integrações (8) | Google Calendar, WhatsApp, E-mail |
| 🟢 P3 | Perfil Usuário (5), Perfil Clínica (6), WhatsApp (7) | Complementares |




---

## 🧑‍💻 Jornada de Criação de Conta e Onboarding Personalizado

### Objetivo
Após o cadastro (e-mail/senha ou Google), o usuário passa por uma **jornada guiada de perguntas** que define o perfil da clínica, personaliza o ambiente visual e habilita/desabilita módulos conforme o tipo de unidade e o plano escolhido.

### Fluxo de Onboarding (Stepper)

| Etapa | Tela | Descrição |
|-------|------|-----------|
| 1 | **Tipo de Unidade** | Seleção do tipo: **UBS**, **UPA**, **APS** ou **Clínica Privada**. Cada tipo define o perfil visual padrão, os módulos habilitados e a experiência personalizada. Salva em `tb_clinica.tipo`. |
| 2 | **Dados da Clínica** | Nome fantasia, Razão social (opcional para públicas), CNPJ/CNES, e-mail institucional, telefone, endereço com busca por CEP. Salva em `tb_clinica`. |
| 3 | **Perfil de Uso** | Perguntas para personalização: _"Quantos profissionais atuam na unidade?"_, _"Qual o volume médio de consultas por dia?"_, _"Quais especialidades são oferecidas?"_, _"A unidade já utiliza sistema de agendamento digital?"_, _"Qual o principal desafio? (absenteísmo / organização / comunicação com paciente)"_. Respostas salvas em `tb_clinica.perfilUso`. |
| 4 | **Escolha do Plano** | Tela `choose-plan` com planos de `tb_plans`. Planos públicos (UBS/UPA/APS) veem o **Público Ilimitado** em destaque. Clínicas privadas veem Essencial, Profissional e Enterprise. Salva em `tb_plan_user`. |
| 5 | **Personalização Visual** | Pré-visualização do tema com as cores do plano/tipo. O usuário pode ajustar cores primárias, modo claro/escuro, e tamanho de fonte. Salva em `tb_limit_app` (campos de tema). |
| 6 | **Confirmação** | Resumo completo de tudo que foi configurado. Botão "Começar a usar". Redireciona para o Dashboard Home. |

### Regras por Tipo de Unidade

| Tipo | Módulos Habilitados | Módulos Desabilitados | Tema Padrão |
|------|--------------------|-----------------------|-------------|
| **UBS** | Agendamentos, Absenteísmo, Tickets, Previsão de Faltas, Recepção | Financeiro (parcial), Agendamento Inteligente B2B | Azul institucional (#1565C0) com verde SUS (#2E7D32) |
| **UPA** | Agendamentos, Tickets (prioridade alta), Recepção | Financeiro, Agendamento Inteligente B2B, Previsão de Faltas | Vermelho urgência (#C62828) com azul (#1565C0) |
| **APS** | Agendamentos, Absenteísmo, Previsão de Faltas, Tickets | Financeiro (parcial), Agendamento Inteligente B2B | Verde saúde da família (#2E7D32) com azul (#1565C0) |
| **Clínica Privada** | Todos os módulos | Nenhum | Azul premium (#1E88E5) com acentos configuráveis |

### Coleções Firestore Envolvidas
- `tb_clinica` — escrita (dados da clínica + campo `perfilUso` + campo `tipo`)
- `tb_plan_user` — escrita (vínculo usuário ↔ plano)
- `tb_plans` — leitura (planos disponíveis)
- `tb_limit_app` — escrita (limites e configurações visuais do plano)
- `users` — escrita (vincular o `clinicId` ao usuário)

---

## 📑 Índice de Módulos

| # | Módulo | Pasta | Descrição |
|---|--------|-------|-----------|
| 1 | Absenteísmo | `features/absenteismo/` | Analytics de faltas, cancelamentos e tendências |
| 2 | Criar Agendamento | `features/agendamentos/criar/` | Fluxo completo para novo agendamento |
| 3 | Financeiro | `features/financeiro/` | Receitas, serviços, métricas financeiras |
| 4 | Modo AI (Agente de IA) | `features/ia/` | Chat IA, relatórios, análise preditiva, agendamento inteligente B2B |
| 5 | Modo Recepção | `features/recepcao/` | Redirecionamento para plataforma externa |
| 6 | Atendimento ao Paciente (Tickets) | `features/tickets/` | Sistema de tickets com filas e SLA |
| 7 | Previsão de Faltas | `features/previsao_faltas/` | Predição de risco de ausência via ML/IA |
| 8 | Integrações | `features/integracoes/` | Google Calendar, WhatsApp (Z-API), E-mail, Push |
| 9 | **Configurações do Sistema** | `features/configuracoes/` | Aparência, acessibilidade, notificações, dados |
| 10 | **Simulador (Monte Carlo)** | `features/monte_carlo/` | Distribuição de faltas do dia e decisão de overbooking por slot |
| 11 | **Projeção 12 meses** | `features/projecao_12m/` | Cenário de continuidade x intervenção, cadeia de Markov e receita defensável |

---

## ⚙️ Módulo 9 — Configurações do Sistema (`features/configuracoes/`)

### Objetivo
Centralizar todas as preferências do usuário e da clínica: aparência visual, tipografia, tema, acessibilidade, notificações, dados e configurações avançadas. As configurações são persistidas localmente (SharedPreferences) para resposta instantânea e sincronizadas com o Firestore para consistência multi-dispositivo.

### Estrutura de Pastas

```
features/configuracoes/
├── screens/
│   ├── configuracoes_hub_screen.dart
│   ├── aparencia_screen.dart
│   ├── tipografia_screen.dart
│   ├── tema_screen.dart
│   ├── acessibilidade_screen.dart
│   ├── notificacoes_screen.dart
│   ├── dados_privacidade_screen.dart
│   └── avancado_screen.dart
├── widgets/
│   ├── config_section_card.dart
│   ├── color_picker_tile.dart
│   ├── font_size_slider.dart
│   ├── theme_preview_card.dart
│   ├── toggle_setting_tile.dart
│   └── config_reset_dialog.dart
├── models/
│   ├── app_settings.dart
│   ├── theme_config.dart
│   └── accessibility_config.dart
└── providers/
    └── configuracoes_provider.dart
```

### Funcionalidades Detalhadas

#### 🎨 CFG-01 — Configurações de Aparência (Cores)

| Sub-ID | Funcionalidade | Descrição |
|--------|----------------|-----------|
| CFG-01a | Cor primária | Seletor de cor (color picker) para definir a cor principal da interface. Opções pré-definidas por tipo de unidade + cor customizada. Aplica em botões, AppBar, indicadores, badges. |
| CFG-01b | Cor de destaque (accent) | Cor secundária para elementos de ação, links e realces. |
| CFG-01c | Cor de fundo | Fundo principal e fundo dos cards. Opções: branco, cinza claro, cinza escuro, azul escuro, preto. |
| CFG-01d | Paletas pré-definidas | Paletas curadas por tipo de unidade: **Institucional** (UBS/APS), **Urgência** (UPA), **Premium** (Privada), **Neutro**, **Alto Contraste**. Seleção via card com preview. |
| CFG-01e | Preview em tempo real | Enquanto o usuário altera as cores, um mini-preview mostra como ficará a interface (AppBar, botão, card, texto). |

#### 🔤 CFG-02 — Configurações de Tipografia (Fonte e Tamanho)

| Sub-ID | Funcionalidade | Descrição |
|--------|----------------|-----------|
| CFG-02a | Família de fontes | Seleção entre famílias: **Inter** (padrão), **Poppins**, **Roboto**, **Outfit**, **Nunito**, **Open Sans**. Preview de cada fonte ao lado do nome. |
| CFG-02b | Tamanho da fonte (escala) | Slider com 5 níveis: **Muito pequena** (0.85×), **Pequena** (0.92×), **Normal** (1.0×), **Grande** (1.1×), **Muito grande** (1.25×). Aplica multiplicador global no `textTheme`. |
| CFG-02c | Peso da fonte | Toggle entre **Normal** (w400) e **Semibold** (w600) para textos do corpo. Headers mantêm sempre bold. |
| CFG-02d | Espaçamento entre linhas | Slider: **Compacto** (1.2), **Normal** (1.5), **Espaçoso** (1.8). Para leitura confortável. |
| CFG-02e | Preview de texto | Bloco de texto de exemplo com título, subtítulo e corpo que reflete as configurações em tempo real. |

#### 🌗 CFG-03 — Configurações de Tema

| Sub-ID | Funcionalidade | Descrição |
|--------|----------------|-----------|
| CFG-03a | Modo de tema | Seleção entre: **Claro**, **Escuro**, **Automático** (segue o SO). Toggle com ícones de sol/lua/auto. |
| CFG-03b | Contraste do tema | Slider: **Suave** (sombras e bordas sutis), **Normal** (padrão), **Alto contraste** (bordas fortes, cores vivas). |
| CFG-03c | Cantos dos componentes | Slider: **Quadrado** (0px), **Suave** (8px), **Arredondado** (16px — padrão), **Pílula** (24px). Aplica no `borderRadius` global. |
| CFG-03d | Animações | Toggle para habilitar/desabilitar micro-animações e transições de página. Útil para dispositivos mais lentos. |
| CFG-03e | Tema da clínica | Se o administrador definiu cores na `tb_limit_app`, exibir opção "Usar tema da clínica" que aplica as cores institucionais. |

#### ♿ CFG-04 — Configurações de Acessibilidade

| Sub-ID | Funcionalidade | Descrição |
|--------|----------------|-----------|
| CFG-04a | Alto contraste | Toggle que ativa modo de alto contraste: bordas mais grossas, cores mais saturadas, fundo sólido sem gradientes. |
| CFG-04b | Escala de texto acessível | Override do tamanho de fonte para escala ≥1.3× independente da configuração de tipografia. |
| CFG-04c | Leitor de tela | Garantir `Semantics` em todos os widgets interativos. Toggle para exibir labels descritivos adicionais em gráficos e ícones. |
| CFG-04d | Reduzir movimento | Desabilita todas as animações: transições de página, micro-interações, gráficos animados. Respeita `MediaQuery.disableAnimations`. |
| CFG-04e | Daltonismo | Filtros de cor para os principais tipos: **Protanopia** (vermelho-verde), **Deuteranopia** (verde-vermelho), **Tritanopia** (azul-amarelo). Aplica `ColorFilter` no tema dos gráficos e badges de status. |
| CFG-04f | Tamanho dos alvos de toque | Toggle para aumentar o tamanho mínimo dos botões e áreas de toque para 48×48dp (padrão WCAG). |
| CFG-04g | Feedback tátil | Toggle para habilitar/desabilitar vibração ao tocar em botões e ações. |

#### 🔔 CFG-05 — Configurações de Notificações

| Sub-ID | Funcionalidade | Descrição |
|--------|----------------|-----------|
| CFG-05a | Push notifications | Toggle geral + toggles por evento: **Novo agendamento**, **Cancelamento**, **Lembrete de consulta**, **Alerta de risco**, **Relatório gerado**, **Ticket atribuído**. |
| CFG-05b | E-mail | Toggle por tipo: **Resumo diário**, **Alertas críticos**, **Relatórios semanais**. |
| CFG-05c | Sons | Toggle para habilitar som de notificação no app. Seleção de tom entre 3 opções. |
| CFG-05d | Horário de silêncio (DND) | Configurar horário de não perturbe: **Início** (ex: 22:00) e **Fim** (ex: 07:00). Notificações ficam silenciosas nesse período. |

#### 🗃️ CFG-06 — Dados e Privacidade

| Sub-ID | Funcionalidade | Descrição |
|--------|----------------|-----------|
| CFG-06a | Limpar cache | Botão para limpar dados em cache (SharedPreferences, imagens, cache de rede). Exibe tamanho atual do cache. |
| CFG-06b | Exportar meus dados | Botão para exportar dados do perfil e configurações em JSON (conformidade LGPD). |
| CFG-06c | Excluir conta | Botão com confirmação tripla (modal + digitação do e-mail + timer de 10s) que exclui a conta do Firebase Auth e marca o usuário como `deleted` no Firestore. |
| CFG-06d | Sessões ativas | Lista de dispositivos/navegadores com sessão ativa. Opção de encerrar sessão em outros dispositivos. |
| CFG-06e | Logout / Sair | Botão de "Sair" (Logout) localizado de forma acessível na tela principal de configurações (main hub) e no final da seção de Privacidade. Limpa os dados de sessão do Firebase Auth, limpa o token local, e redireciona para a tela de Login. |

#### 🔧 CFG-07 — Configurações Avançadas

| Sub-ID | Funcionalidade | Descrição |
|--------|----------------|-----------|
| CFG-07a | Idioma | Seleção de idioma: **Português (BR)** (padrão), **Inglês**, **Espanhol**. Usa `intl` para internacionalização. |
| CFG-07b | Formato de data | Seleção: **DD/MM/AAAA** (padrão BR), **MM/DD/AAAA**, **AAAA-MM-DD**. |
| CFG-07c | Formato de hora | Toggle: **24h** (padrão) ou **12h (AM/PM)**. |
| CFG-07d | Fuso horário | Seleção de timezone. Padrão: `America/Sao_Paulo`. |
| CFG-07e | Modo desenvolvedor | Toggle oculto (tap 7x no número da versão): ativa logs no console, indicadores de performance, inspetor de rede. |
| CFG-07f | Sobre o aplicativo | Versão, build, licenças open source, links para: Termos de Uso, Política de Privacidade, Central de Ajuda. |
| CFG-07g | Restaurar padrões | Botão para resetar TODAS as configurações visuais para os valores padrão do tipo de unidade. Modal de confirmação obrigatório. |

### Modelo de Dados

```dart
// models/app_settings.dart
class AppSettings {
  // Aparência
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final String paletteId;       // 'institucional', 'urgencia', 'premium', 'neutro', 'alto_contraste'

  // Tipografia
  final String fontFamily;       // 'Inter', 'Poppins', 'Roboto', etc.
  final double fontScale;        // 0.85 a 1.25
  final FontWeight bodyWeight;
  final double lineHeight;       // 1.2, 1.5, 1.8

  // Tema
  final ThemeMode themeMode;     // light, dark, system
  final double contrastLevel;    // 0.0 (suave) a 1.0 (alto)
  final double borderRadius;     // 0, 8, 16, 24
  final bool animationsEnabled;
  final bool useClinicTheme;

  // Acessibilidade
  final bool highContrast;
  final bool reduceMotion;
  final bool largerTouchTargets;
  final bool hapticFeedback;
  final String? colorBlindFilter; // null, 'protanopia', 'deuteranopia', 'tritanopia'
  final bool screenReaderLabels;

  // Notificações
  final Map<String, bool> pushToggles;
  final Map<String, bool> emailToggles;
  final bool soundEnabled;
  final String? dndStart;        // '22:00'
  final String? dndEnd;          // '07:00'

  // Avançado
  final String locale;           // 'pt_BR', 'en_US', 'es_ES'
  final String dateFormat;       // 'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'
  final bool use24HourFormat;
  final String timezone;
  final bool developerMode;
}
```

### Persistência

| Camada | Tecnologia | Responsabilidade |
|--------|------------|------------------|
| **Local** | `SharedPreferences` | Resposta instantânea, aplicação imediata do tema ao abrir o app. Cache de todas as configurações como JSON serializado. |
| **Remota** | Firestore (`tb_limit_app`) | Sincronização multi-dispositivo. Campos: `temaConfig`, `acessibilidadeConfig`, `notificacoesConfig`. Merge com dados locais ao login. |
| **Padrão** | Código (const) | Valores padrão por tipo de unidade (`defaultSettingsFor(ClinicType type)`). Usados no primeiro acesso e ao restaurar padrões. |

### Coleções Firestore Utilizadas
- `tb_limit_app` — leitura/escrita (configurações visuais do plano: `temaConfig`, `coresPrimaria`, `coresSecundaria`, fontes)
- `tb_clinica` — leitura (tipo de unidade, para determinar defaults)
- `tb_plan_user` — leitura (plano ativo, para verificar quais configurações são permitidas)
- `users` — leitura/escrita (preferências individuais do usuário: `settings`)

### Referência Visual
- Inspiração: telas de configuração do Google Material You, com seções expansíveis, previews em tempo real e toggles fluidos.

---
## 🚀 Roadmap de Melhorias e Recursos Avançados (2026-06-24)

> Auditoria do estado atual + especificação de novos recursos. Implementação por
> **AGENT TEAMS** em paralelo: cada agente cria **apenas** arquivos dentro da sua
> pasta `lib/features/<modulo>/` (+ teste). O **Agente Líder** integra rotas,
> navegação e `ModuleRegistry`.

### 📊 Estado atual (implementado)
Home, Agendamentos, Absenteísmo, IA, Perfil Usuário, Perfil Clínica, WhatsApp,
Autenticação (login/cadastro/Google/biometria/recuperação), Planos
(`tb_plans` via Firestore), Mapa de Módulos (`/arquitetura` com habilitar/
desabilitar), Configurações do Sistema (Aparência, Tipografia, Tema,
Acessibilidade, Notificações, Dados, Avançado), Editor de Logotipo, Command
Palette, tema reativo às preferências, e wiring de Firestore para clínicas/planos.

### 🧩 Lacunas identificadas (faltam)
- **Pacientes**: não há módulo dedicado (mockup `area_e_jornada_do_paciente.png`
  não implementado). Falta lista, prontuário, jornada e reputação/risco.
- **Recepção**: registrada como planejada, sem UI (check-in, fila, painel de senhas).
- **Central de Notificações** in-app (feed, badge, marcar como lida).
- **Relatórios**: geração/visualização e exportação (CSV/PDF/print).
- **Criar Agendamento**: fluxo completo com validação de disponibilidade.
- **Onboarding / Perfil de Uso** (perguntas de personalização → `tb_clinica.perfilUso`).
- **i18n real** (ARB) — hoje só troca de locale sem traduções.
- **Estados de carregamento/erro/vazio** padronizados (skeletons).
- **Sincronização remota** das configurações e do plano (`tb_limit_app`/`tb_plan_user`).

---

### 👥 Módulo — Pacientes (`features/pacientes/`)
Lista de pacientes com busca/filtro, e tela de **detalhe/jornada do paciente**
seguindo `.specify/Designer/area_e_jornada_do_paciente.png`.

| ID | Funcionalidade |
|----|----------------|
| PAC-01 | Lista de pacientes (busca por nome, filtro por risco) |
| PAC-02 | Cartão do paciente (idade, ID, próximo atendimento, risco de falta) |
| PAC-03 | Jornada atual (timeline: Agendado → Confirmado → Pré-check → Consulta) |
| PAC-04 | Histórico de presença (atendidos × faltas) |
| PAC-05 | Notas clínicas (lista + adicionar) |
| PAC-06 | Ações: Marcar falta / Concluir consulta / Contato |

### 🛎️ Módulo — Recepção (`features/recepcao/`)
| ID | Funcionalidade |
|----|----------------|
| REC-01 | Check-in de pacientes do dia |
| REC-02 | Fila de espera com ordem de chamada e tempo de espera |
| REC-03 | Chamar próximo (painel de senha) |
| REC-04 | KPIs do balcão (na fila, atendidos, tempo médio) |

### 🔔 Módulo — Central de Notificações (`features/notificacoes_centro/`)
| ID | Funcionalidade |
|----|----------------|
| NOT-01 | Feed de notificações (agendamento, cancelamento, risco, relatório) |
| NOT-02 | Filtro por tipo e por não lidas |
| NOT-03 | Marcar como lida / marcar todas |
| NOT-04 | Badge de contagem de não lidas |

### 📑 Módulo — Relatórios (`features/relatorios/`)
| ID | Funcionalidade |
|----|----------------|
| REL-01 | Lista de relatórios gerados (IA e operacionais) |
| REL-02 | Visualização do relatório (texto + métricas) |
| REL-03 | Exportar (copiar/baixar CSV; imprimir) |
| REL-04 | Gerar novo relatório por período/tipo |

### 🧱 Melhorias transversais (Agente Líder / core)
- `core/widgets/async_states.dart`: `LoadingView`, `EmptyView`, `ErrorView`, `SkeletonCard`.
- Central de notificações alimenta badge no `AppHeader`/Drawer.
- Registrar os novos módulos no `ModuleRegistry` e no roteador.


---

## 👨‍⚕️ Módulo — Equipe Médica (`features/equipe_medica/`)

> **Status (2026-07): Implementado.** Ver `update_data.md` §"Equipe Médica e
> Perfil do Médico". A estrutura real é achatada (sem subpastas
> `screens/widgets/models/providers`): `equipe_medica_screen.dart`,
> `medico_detalhe_screen.dart`, `medico_form_screen.dart`,
> `medico_agenda_screen.dart`. Dados via `clinicDoctorsProvider` (Firestore
> `tb_medicos` filtrado por `idclinica`, com CRUD e upload de foto ao Storage).
> Escala de atendimento (`scalaMedico`) com presets + personalizada. Gráficos e
> carrossel no detalhe. Absenteísmo por médico (AB-09) foi implementado no
> módulo Absenteísmo.

### Objetivo
Módulo para listagem, busca e gestão completa (CRUD) de todos os profissionais médicos vinculados à clínica selecionada. Permite ao administrador da clínica visualizar a equipe, adicionar novos médicos, editar informações e desativar profissionais.

### Estrutura de Pastas

```
features/equipe_medica/
├── screens/
│   ├── equipe_medica_list_screen.dart
│   ├── medico_detalhe_screen.dart
│   ├── medico_form_screen.dart            # Criar / Editar médico
│   └── medico_configuracoes_screen.dart   # Configurações avançadas do médico
├── widgets/
│   ├── medico_card.dart
│   ├── medico_search_bar.dart
│   ├── especialidade_filter_chips.dart
│   ├── status_badge.dart
│   ├── estatisticas_resumo_card.dart
│   └── medico_skeleton.dart
├── models/
│   ├── medico.dart
│   └── medico_filtro.dart
└── providers/
    └── equipe_medica_provider.dart
```

### Funcionalidades Detalhadas

| ID | Funcionalidade | Descrição | Componente |
|----|----------------|-----------|------------|
| EM-01 | Lista da equipe médica | Listagem paginada de todos os médicos da clínica selecionada. Cada card exibe: **foto de perfil**, **nome completo**, **CRM**, **especialidades** (chips), **status** (ativo/inativo badge), **ticket médio** (valor do `tiket`). Ordenação por nome (A-Z) ou por total de consultas do mês. | `equipe_medica_list_screen.dart` + `medico_card.dart` |
| EM-02 | Busca e filtros | Barra de busca por **nome** ou **CRM**. Filtros por: **especialidade** (chips selecionáveis a partir das especialidades existentes na clínica), **status** (ativo/inativo/todos). | `medico_search_bar.dart` + `especialidade_filter_chips.dart` |
| EM-03 | Cadastrar novo médico | Formulário completo para criar novo registro em `tb_medicos`. Campos obrigatórios: **Nome completo**, **E-mail**, **Telefone**, **CRM**, **Especialidades** (multiselect), **Foto de perfil** (upload câmera/galeria). Campos opcionais: **Endereço**, **Biografia**, **Experiência**, **Valor do ticket** (`tiket`). Ao salvar, `idclinica` é preenchido automaticamente com a clínica selecionada, `status = true`, `dataCriacao = now()`. | `medico_form_screen.dart` |
| EM-04 | Editar médico | Mesmo formulário de EM-03, pré-preenchido com os dados atuais. Ao salvar, atualiza `dataAtualizacao = now()`. Registra histórico de alteração em `tb_medicos_config_history`. | `medico_form_screen.dart` |
| EM-05 | Visualizar detalhes | Tela de detalhe do médico com todas as informações: **Dados pessoais** (foto, nome, CRM, e-mail, telefone, endereço), **Biografia e experiência**, **Especialidades**, **Estatísticas** (card com `totalConsultasMes`, `mediaFaltas`, `taxaOcupacaoMedia`, `overbookingUtilizado`, `realizacoesRealocadas`), **Horário de funcionamento** (tabela de dias/horários), **Link para a agenda em tempo real** (navega para timeline do médico em `features/agendamentos/`). | `medico_detalhe_screen.dart` + `estatisticas_resumo_card.dart` |
| EM-06 | Ativar/Desativar médico | Toggle de status (`status: true/false`) com confirmação via modal. Médico desativado não aparece em seleções de agendamento mas permanece nos registros. Ao desativar, exibir alerta se médico possui agendamentos futuros. | `medico_detalhe_screen.dart` |
| EM-07 | Configurações avançadas | Tela dedicada para configurar: **Horário de funcionamento** (`horarioFuncionamento`), **Limites de segurança** (`limitesSeguranca`), **Overbooking por dia** (`overbookingConfig`), **Overbooking por período** (`overbookingPeriodo`), **Configurações de realocação** (`realocacao`), **Notificações** (`notificacao`), **Prioridades** (`prioridades`), **Máximo de overbooking geral** (`maxOverbook`), **Escala** (`scalaMedico`). Cada alteração salva gera registro em `tb_medicos_config_history`. | `medico_configuracoes_screen.dart` |
| EM-08 | Excluir médico | Soft delete (altera `status = false` e adiciona campo `deletedAt`). Confirmação dupla via modal: "Tem certeza? Este médico possui X agendamentos futuros." Não remove o documento do Firestore para manter integridade dos agendamentos existentes. | `medico_detalhe_screen.dart` |

### Validações
- **CRM:** Formato válido (letras do estado + números), unicidade por clínica.
- **E-mail:** Formato válido, unicidade por clínica.
- **Telefone:** Formato brasileiro (com DDD).
- **Especialidades:** Pelo menos uma especialidade deve ser selecionada.
- **Nome completo:** Mínimo 3 caracteres.
- **Foto de perfil:** Formatos aceitos: JPG, PNG. Máximo 5MB. Redimensionar para 400×400px.
- **Limite de médicos:** Verificar `tb_limit_app.lt_users` antes de permitir novo cadastro.

### Coleções Firestore Utilizadas
- `tb_medicos` — CRUD completo (filtrado por `idclinica`)
- `tb_medicos_config_history` — escrita (log de alterações de configuração)
- `tb_hour_atendimento_medico` — leitura (horários detalhados de atendimento)
- `tb_clinica` — leitura (dados da clínica para vincular)
- `tb_limit_app` — leitura (verificar limite de profissionais do plano)
- `tb_agendamentos` — leitura (verificar agendamentos futuros ao desativar/excluir)

### Referência Visual
- `.specify/Designer/agenda_timeline_medico.png` (referência para card de médico)

### Permissões
- Acessível para usuários com `roles` contendo **"admin"** ou **"gestor"**.
- Usuários com role **"medico"** podem apenas visualizar a lista (sem ações de CRUD).

---

## 🩺 Módulo — Perfil do Médico (`features/perfil_medico/`)

> **Status (2026-07): Parcial.** Os recursos de perfil já entregues vivem em
> `features/equipe_medica/` (detalhe do médico): dados pessoais, foto (upload ao
> Storage), estatísticas com gráficos (PM-01), agenda em tempo real filtrada por
> `idmedico` (PM-09) e carrossel de consultas. Pendentes: Google Agenda (PM-03) e
> gestão de clínicas vinculadas (PM-04..PM-08). Ver `update_data.md`.

### Objetivo
Módulo de perfil individual do médico autenticado. Permite que o próprio médico visualize e edite seus dados pessoais, conecte sua Google Agenda para sincronização de horários, gerencie os perfis de clínicas vinculadas (criar, editar, excluir, visualizar), e acesse sua agenda em tempo real.

### Estrutura de Pastas

```
features/perfil_medico/
├── screens/
│   ├── perfil_medico_screen.dart            # Tela principal do perfil
│   ├── editar_perfil_medico_screen.dart      # Edição de dados pessoais
│   ├── google_agenda_screen.dart             # Conexão e config Google Calendar
│   ├── clinicas_vinculadas_screen.dart        # Lista de clínicas do médico
│   ├── clinica_form_screen.dart               # Criar / Editar perfil de clínica
│   ├── clinica_detalhe_screen.dart             # Visualizar perfil da clínica
│   └── agenda_realtime_screen.dart            # Agenda do médico em tempo real
├── widgets/
│   ├── perfil_header_card.dart
│   ├── info_tile.dart
│   ├── google_agenda_status_widget.dart
│   ├── clinica_vinculada_card.dart
│   ├── agenda_timeline_widget.dart
│   ├── agenda_slot_card.dart
│   └── sync_status_indicator.dart
├── models/
│   ├── perfil_medico.dart
│   ├── google_calendar_config.dart
│   └── clinica_vinculada.dart
└── providers/
    ├── perfil_medico_provider.dart
    └── google_agenda_provider.dart
```

### Funcionalidades Detalhadas

| ID | Funcionalidade | Descrição | Componente |
|----|----------------|-----------|------------|
| PM-01 | Visualizar perfil | Tela principal exibindo dados completos do médico logado: **Foto de perfil** (grande, com botão de editar), **Nome completo**, **CRM**, **E-mail**, **Telefone**, **Endereço**, **Especialidades** (chips), **Biografia**, **Experiência**, **Valor do ticket**, **Status** (ativo/inativo), **Estatísticas** resumidas (card com `totalConsultasMes`, `mediaFaltas`, `taxaOcupacaoMedia`). Seções de acesso rápido: "Minha Agenda", "Minhas Clínicas", "Google Agenda". | `perfil_medico_screen.dart` + `perfil_header_card.dart` |
| PM-02 | Editar dados pessoais | Formulário de edição dos dados pessoais do médico: **Foto de perfil** (upload câmera/galeria com crop), **Nome completo**, **E-mail**, **Telefone**, **Endereço**, **Biografia** (textarea), **Experiência** (textarea), **Especialidades** (multiselect com autocomplete), **Valor do ticket**. CRM é **somente leitura** (não editável pelo médico). Ao salvar, atualiza `dataAtualizacao` e registra em `tb_medicos_config_history`. | `editar_perfil_medico_screen.dart` |
| PM-03 | Conectar Google Agenda | Fluxo de autenticação OAuth2 com Google Calendar API. **Status da conexão:** indicador visual (🟢 Conectado, 🔴 Desconectado, 🟡 Sincronizando). **Configurações de sincronização:** selecionar calendário, escolher direção da sincronização (Vitta → Google, Google → Vitta, bidirecional), intervalo de sync (a cada 5/15/30/60 minutos). **Ações:** Conectar conta, Desconectar conta, Forçar sincronização manual, Ver log de sincronizações. Os agendamentos do Vitta App são replicados como eventos no Google Calendar e vice-versa. | `google_agenda_screen.dart` + `google_agenda_status_widget.dart` + `sync_status_indicator.dart` |
| PM-04 | Listar clínicas vinculadas | Lista de todas as clínicas onde o médico está vinculado. Cada card exibe: **Logo da clínica** (`photoClinica`), **Nome** (`nome`), **Status** (`status`), **Telefone**, **E-mail**. Botões de ação: 👁️ Visualizar, ✏️ Editar, 🗑️ Excluir vínculo. Botão FAB "+" para criar novo perfil de clínica. | `clinicas_vinculadas_screen.dart` + `clinica_vinculada_card.dart` |
| PM-05 | Criar perfil de clínica | Formulário para criar uma nova clínica no sistema. Campos: **Nome** (nome fantasia), **E-mail** institucional, **Telefone**, **Logo** (upload de imagem), **Status** (ativo por padrão). Ao salvar, cria documento em `tb_clinica` e vincula o `idclinica` ao documento do médico em `tb_medicos`. Também cria registros iniciais em `tb_limit_app` com limites do plano Free. | `clinica_form_screen.dart` |
| PM-06 | Editar perfil de clínica | Mesmo formulário de PM-05, pré-preenchido com dados da clínica selecionada. Permite alterar: **Nome**, **E-mail**, **Telefone**, **Logo**, **Status**. Somente o médico que criou a clínica (ou admin) pode editar. | `clinica_form_screen.dart` |
| PM-07 | Excluir perfil de clínica | Exclusão do vínculo médico-clínica com confirmação dupla. Se o médico é o **único** vinculado à clínica, exibir alerta: "Esta clínica ficará sem profissionais. Deseja continuar?". Soft delete: altera `status` da clínica para "inativo". Não exclui agendamentos existentes. Verifica se existem agendamentos futuros antes de permitir. | `clinica_detalhe_screen.dart` |
| PM-08 | Visualizar perfil da clínica | Tela somente leitura com todos os dados da clínica: **Logo**, **Nome**, **E-mail**, **Telefone**, **Status**, **Data de cadastro**. Seção com lista de outros médicos vinculados à mesma clínica (dados de `tb_medicos` filtrados por `idclinica`). Seção com métricas da clínica: total de agendamentos do mês, total de médicos, próximo agendamento. | `clinica_detalhe_screen.dart` |
| PM-09 | Agenda em tempo real | Visualização da agenda pessoal do médico em tempo real usando **Firestore listeners** (snapshots). Exibe timeline vertical do dia atual com todos os agendamentos (dados de `tb_agendamentos` filtrados por `idmedico`). Cada slot mostra: **Horário**, **Nome do paciente**, **Tipo de consulta**, **Status** (código de cores: 🟢 Confirmado, 🔴 Cancelado, 🟡 Pré-agendado, 🔵 Em atendimento, ⚪ Concluído). Navegação por dia (swipe esquerda/direita ou date picker). Indicador visual do horário atual (linha vermelha). Atualização automática sem refresh manual. | `agenda_realtime_screen.dart` + `agenda_timeline_widget.dart` + `agenda_slot_card.dart` |

### Regras de Negócio
- **Autenticação:** O médico só pode ver/editar **seu próprio perfil**. O ID do médico é obtido a partir do `uid` do Firebase Auth cruzado com `tb_medicos`.
- **CRM imutável:** O campo CRM não pode ser alterado após o cadastro (somente por admin via módulo Equipe Médica).
- **Clínicas:** Um médico pode estar vinculado a **múltiplas clínicas** (campo `idclinica` em `tb_medicos` pode ser alterado, ou o médico pode ter múltiplos documentos em `tb_medicos`, um por clínica).
- **Google Agenda:** Token OAuth2 armazenado de forma segura (Secure Storage no mobile, encrypted no web). Refresh token com renovação automática. Respeitar rate limits da Google Calendar API (300 requests/min).
- **Limite de clínicas:** Verificar `tb_plan_user` → `tb_plans` para saber o limite de clínicas do plano do médico antes de permitir criar nova clínica.
- **Agenda em tempo real:** Usar `Firestore.instance.collection('tb_agendamentos').where('idmedico', isEqualTo: medicoRef).snapshots()` para updates em tempo real. Limitar a consultas do dia selecionado para otimizar leituras.

### Validações
- **Foto de perfil:** JPG/PNG, máximo 5MB, crop para 400×400px.
- **E-mail:** Formato válido.
- **Telefone:** Formato brasileiro com DDD.
- **Biografia:** Máximo 1000 caracteres.
- **Experiência:** Máximo 500 caracteres.
- **Especialidades:** Pelo menos uma selecionada.
- **Nome da clínica:** Mínimo 3 caracteres, máximo 100.

### Coleções Firestore Utilizadas
- `tb_medicos` — leitura/escrita (dados do perfil do médico logado)
- `tb_medicos_config_history` — escrita (log de alterações no perfil)
- `tb_clinica` — CRUD (criar, ler, editar, excluir clínicas vinculadas)
- `tb_agendamentos` — leitura em tempo real (agenda do dia, filtrada por `idmedico`)
- `tb_hour_agenda` — leitura (slots de horários disponíveis do médico)
- `tb_hour_atendimento_medico` — leitura (horários de atendimento configurados)
- `tb_plan_user` / `tb_plans` — leitura (verificar limites do plano)
- `tb_limit_app` — escrita (criar limites ao criar nova clínica)
- `tb_views_medicos` — leitura (avaliações/visualizações do perfil do médico)

### Integração Google Calendar API
```dart
// google_agenda_provider.dart
// Scopes necessários:
//   - https://www.googleapis.com/auth/calendar.readonly
//   - https://www.googleapis.com/auth/calendar.events
// Pacotes Flutter:
//   - google_sign_in: ^latest
//   - googleapis: ^latest (CalendarApi)
//   - extension_google_sign_in_as_googleapis_auth: ^latest
// Fluxo:
//   1. Login via google_sign_in com scopes de calendar
//   2. Obter AuthClient autenticado
//   3. Usar CalendarApi para listar/criar/atualizar eventos
//   4. Salvar refreshToken em secure_storage
//   5. Sincronizar agendamentos: tb_agendamentos ↔ Google Calendar Events
```

### Referência Visual
- `.specify/Designer/agenda_timeline_medico.png` (timeline da agenda em tempo real)
- `.specify/Designer/Unidade de saude.png` (referência para tela de perfil de clínica)

### Permissões
- **PM-01, PM-02:** Acessível pelo próprio médico autenticado.
- **PM-03:** Acessível pelo próprio médico autenticado.
- **PM-04 a PM-08:** Acessível pelo próprio médico (para suas clínicas) ou por admin.
- **PM-09:** Acessível pelo próprio médico (sua agenda) ou admin (qualquer agenda).

---

## 🎲 Módulo 10 — Simulador de Monte Carlo (`features/monte_carlo/`)

### Objetivo

Responder a uma pergunta operacional: **quantos pacientes cabem amanhã sem
estourar a sala de espera?** A resposta sai da distribuição inteira de faltas,
não da média.

Complementa (não substitui) o módulo **Overbooking**, que é determinístico e
mostra a ocupação já realizada. O Simulador trabalha sobre a agenda ainda em
aberto e devolve probabilidades.

### Quatro decisões de modelagem

| # | Decisão | Por quê |
|---|---------|---------|
| 1 | **Faltas do mesmo dia não são independentes** | Chuva, feriado e ondas respiratórias empurram as faltas do dia na mesma direção. Cópula gaussiana de um fator, que preserva as marginais exatamente — só a dispersão muda. Ignorar isso produz intervalos artificialmente estreitos. |
| 2 | **Três estados, não dois** | Cancelar com antecedência libera a vaga a tempo; faltar não libera nada. Tratar os dois como a mesma coisa superestima a capacidade recuperável do dia. |
| 3 | **Overbooking é decidido por slot** | Uma falta às 16h não libera capacidade para um encaixe às 9h. Casa com o `OverbookingEngine`, que já é médico × hora. |
| 4 | **A fila vem antes do overbooking** | Preencher vaga de fato liberada não cria espera para ninguém; o encaixe especulativo cria. |

### Arquivos

| Arquivo | Papel |
|---------|-------|
| `monte_carlo_models.dart` | `ModeloRisco`, `SimulacaoConfig`, `ConsultaRisco`, `Distribuicao`, `SlotForecast`, `CenarioOverbooking`, `EquidadeRelatorio`, `RecomendacaoFila` |
| `monte_carlo_engine.dart` | Motor puro: cópula de três estados, Poisson-binomial exata, equidade, fila, decisão de encaixes |
| `monte_carlo_metrics.dart` | CRPS, pinball, cobertura, PIT, ECE |
| `monte_carlo_calibracao.dart` | Fase F2: taxas por faixa com IC de Wilson, `phi`, `rho` por momentos, backtest fora da amostra |
| `monte_carlo_isolate.dart` | Amostragem fora da thread de UI via `compute` |
| `monte_carlo_persistencia.dart` | Fase F3: `tb_mc_execucoes`, `tb_mc_decisoes`, `tb_mc_calibracao` |
| `monte_carlo_providers.dart` | Riverpod — derivado de `appointmentsProvider` e `clinicDoctorsProvider` |
| `monte_carlo_historico_demo.dart` | Histórico sintético com parâmetros conhecidos, para o modo demonstração e como oráculo de teste |
| `monte_carlo_screen.dart` | Tela em 5 abas: Decisão, Planejador, **Ações de IA**, Calibração, Parâmetros |
| `ia/acoes_ia.dart` | `AcaoIa` (catálogo), `MontadorContexto` (monta os fatos em Dart a partir do resultado determinístico) |
| `ia/executor_acoes.dart` | `AcoesController` — roda uma ação por vez, checa pré-condições, guarda as respostas |
| `ia/validador_numeros.dart` | `ValidadorNumeros` — confere toda cifra do texto da IA contra a simulação |
| `ia/plano_semanal.dart`, `ia/agente_simulacao.dart` | Planejador semanal: varredura de N dias + leitura da IA sobre o plano |
| `widgets/mc_acoes_ia.dart` | Lista de ações da aba "Ações de IA", agrupada por categoria |
| `widgets/mc_explicar_icone.dart` | Ícone "Explicar" ao lado de cada gráfico — abre a leitura em folha inferior |
| `widgets/mc_planejador_tab.dart` | Aba Planejador: varredura de 3/7/14 dias |
| `widgets/` (demais) | Gráfico de distribuição, abas de Decisão/Calibração/Parâmetros, componentes comuns, ponte para o Overbooking |

### Parâmetro `rho` — e o caminho exato

`rho` é a correlação latente entre desfechos do mesmo dia (típico: 0,02–0,05).

Com **`rho = 0` o motor não simula nada**: devolve as **Poisson-binomiais
exatas** por convolução dinâmica — sem semente, sem erro de amostragem, em
microssegundos. Esse caminho reproduz exatamente o modelo independente da v1.0
e serve de **oráculo** para validar o amostrador nos testes.

### Duas escolhas que mudam a leitura

- **Base de capacidade.** `Doctor.capacityAt()` já devolve `slotLimit + overbook`.
  Medir contra ela empilha encaixes em cima do overbooking existente. O padrão
  é `BaseCapacidade.fisica` (`slotLimit`); a tela mostra os dois números.
- **Modo de encaixe.** `certo` trata o encaixe como comparecimento garantido
  (limite superior do risco). `probabilistico` convolui com a binomial dos
  encaixes, mas ignora o fator comum do dia para eles — levemente otimista.
  São **limites**, não estimativa única.

### Equidade (§12)

Encaixar num slot aumenta a espera de todos os pacientes daquele slot. A
alocação gulosa só olha risco de estouro, então pode concentrar encaixes nos
slots com mais pacientes de alto risco — que na base costumam ser os de menor
renda e maior distância. `EquidadeRelatorio` mede a razão entre a carga que
cada faixa absorve e a sua presença na agenda; acima do teto (padrão 1,25x) o
cenário é **reprovado mesmo com risco de estouro baixo**.

### Isolamento e persistência

- A simulação é puramente derivada da agenda — funciona igual no modo
  demonstração, sem guarda de `firebaseEnabledProvider`.
- `mcRepositorioProvider` é mock por padrão e sobrescrito em `main` com
  Firebase ativo, igual a `realocacaoServiceProvider`. A implementação recusa
  `clinicId` vazio.
- A ponte no painel de Overbooking é **preguiçosa**: só lê o resultado depois
  que o Simulador foi aberto na sessão (`mcSessaoAtivaProvider`). Sem isso,
  abrir o Overbooking dispararia uma simulação inteira como efeito colateral.

### Histórico sintético — como a calibração é exercitada

`monte_carlo_historico_demo.dart` gera histórico com **parâmetros conhecidos**:
taxas por faixa, correlação diária e sazonalidade (razão de chances por mês,
`ρ` de 0,024 a 0,075). Isso resolve dois problemas ao mesmo tempo:

1. **Modo demonstração:** sem Firebase a agenda não tem histórico, e a aba
   Calibração só sabia dizer "dados insuficientes" — o estimador nunca era
   exercitado antes de encontrar a base real. `mcHistoricoProvider` acrescenta o
   sintético apenas quando o Firebase está desligado, e a aba exibe um banner
   dizendo que os números não descrevem clínica nenhuma.
2. **Oráculo de teste:** se o estimador não recupera o que foi injetado, ele
   está errado. Todo agendamento leva o prefixo `hist_demo_`.

Recuperação medida em 5.178 consultas / 257 dias:

| Faixa | Injetado | Medido | IC 95% |
|---|---|---|---|
| Baixo | 8,2% | 9,3% | 8,3–10,4% |
| Médio | 19,5% | 21,2% | 19,2–23,3% |
| Alto | 34,6% | 35,7% | 32,3–39,2% |

`φ = 1,39`, `ρ = 0,052` com IC95 `[0,017; 0,086]`, cobertura do backtest 88%.

### Incerteza sobre o próprio `ρ`

Um módulo cuja tese é "propague a incerteza" não pode entregar o parâmetro de
dependência como número seco. `rhoIc95` sai de **bootstrap por dia** — reamostra
o dia, não a consulta, porque a dependência é justamente o que quebra a
independência dentro do dia. Quando o intervalo contém zero, `rhoConclusivo` é
`false` e a aba diz que a evidência não é conclusiva.

### Detector de sazonalidade — e por que ele quase nunca dispara

`φ` é sazonal, então um `ρ` congelado erra nos dois extremos do ano. O teste é
de **heterogeneidade entre todos os meses**, não extremo contra extremo:

    Q = Σ nₘ(φₘ − φ̄)² / (2·φ̄²)   ~   χ²(k−1) sob homogeneidade

Comparar extremos é um teste de máximo disfarçado: com dez meses ruidosos algum
sempre se destaca, e corrigir isso exige limiar tão alto que sazonalidade real
deixa de ser detectada.

**Controle verificado:** com 22 a 90 consultas/dia o detector não dispara nem
com sazonalidade injetada — e isso está certo: `φ` de um mês com ~25 dias carrega
erro padrão de ~0,4, maior que o sinal. Com 160/dia ele acerta os dois casos
(dispara com sazonalidade, não dispara sem). Em nenhuma densidade houve falso
positivo. A leitura prática: **clínica pequena não consegue estabelecer
sazonalidade de `φ` com um ano de histórico** — e a tela diz isso em vez de
fingir precisão.

### Origem do risco do paciente

`tb_agendamentos` **não tem campo de risco**; ele vive em `tb_faltas_data`
(`probabilidade_falta`, `risco_falta`). `FirestoreAppointmentService._fromDoc`
passou a ler, em ordem de precedência: probabilidade numérica → rótulo → escore.
`RiskLevel.fromString` devolve `null` quando não reconhece — de propósito: cair
em `low` por omissão faria todo paciente parecer de baixo risco, que é o modo de
falha silenciosa que a estratificação deve evitar.

`Appointment.pFaltaPrevista` carrega a probabilidade individual quando existe. É
estritamente melhor que a faixa categórica — a faixa é um resumo de três níveis
de algo que o pipeline já calcula como número.

**Atenção:** enquanto o pipeline não denormalizar esses campos no agendamento
(ou alguém não fizer o join com `tb_faltas_data`), a leitura não encontra nada e
o comportamento continua o de antes.

### Calibração — o gargalo real (F2)

As taxas padrão de `ModeloRisco` (6% / 15% / 32%) são **ponto de partida, não
medição**. `MonteCarloCalibracao.estimar` mede na base:

1. Taxa observada por faixa, com intervalo de Wilson — faixa com menos de 50
   consultas mantém o padrão e registra aviso.
2. `phi` = média dos resíduos padronizados ao quadrado (1,0 sob independência).
3. `rho` por momentos, invertendo `Cov(i,j) ≈ rho · pdf(z_i) · pdf(z_j)`.
4. Backtest fora da amostra com cobertura, CRPS, pinball e ECE.

Critério de saída: ≥ 120 dias **e** cobertura do P05–P95 dentro de ±5 pontos
de 90%. A aplicação dos parâmetros medidos é **manual** — a calibração propõe,
a pessoa aceita.

### Limitações conhecidas

- **`phi` é sazonal** e o `rho` da configuração é fixo. Reestimar semanalmente
  é trabalho de operação, ainda não automatizado.
- **A base não separa "paciente cancelou" de "clínica cancelou"** — são eventos
  opostos no mesmo status. Enquanto o transacional não tiver esse campo, a taxa
  de cancelamento fica superestimada. Dependência de produto, não de modelo.
- **A calibração lê `appointmentsProvider`**, limitado à janela que a agenda
  carrega. Para produção o histórico precisa de consulta própria, mais longa.
- **Na web não há isolate**: amostragem pesada trava o frame. Reduzir `nRuns`
  é a saída enquanto a simulação não for fatiada entre frames.
- Fases **F4–F7** (dashboard em sombra, n8n, RIPD, produção) não começaram.

### IA do simulador — ações e tutorial guiado

A aba **Ações de IA** e os ícones "Explicar" ao lado de cada gráfico usam o
mesmo padrão do planejador semanal (`agente_simulacao.dart`), com as mesmas
**três travas**:

1. **Não calcula.** `MontadorContexto` monta os fatos em Dart puro a partir do
   resultado já determinístico (`SimulacaoResultado`/`CalibracaoResultado`). O
   modelo nunca vê a agenda — só o resumo textual que este arquivo produz.
2. **Não aplica.** Toda saída é texto numa folha ou num cartão. Nada é
   gravado na agenda a partir de uma leitura de IA.
3. **Não passa sem conferência.** Cada `ContextoAcao` carrega
   `numerosPermitidos` — o conjunto de cifras extraídas dos próprios fatos.
   `ValidadorNumeros` marca com ⚠️ qualquer número do texto que não veio dali.
   A saída ainda aparece (não é bloqueada) — o aviso é para quem vai agir
   conferir antes.

O catálogo (`AcaoIa.catalogo`) tem duas partes: `AcaoIa.lista` (o que aparece
na aba — explicar o dia, achar o gargalo, testar intervenção, diagnosticar a
calibração, revisar equidade, redigir mensagem da fila, resumo para a gestão)
e as ações de `CategoriaAcao.grafico`, que ficam **fora** de `lista` e só são
disparadas pelo ícone "Explicar" ao lado do gráfico correspondente — listá-las
nos dois lugares duplicaria a oferta (bug real, pego pelo teste de widget
`monte_carlo_screen_test.dart` antes de chegar ao usuário).

`AcoesController` roda **uma ação por vez** e expõe `indisponivel(acao)`, que
barra o botão antes de qualquer chamada de IA quando a simulação ainda não
resolveu, a data não tem agenda, a fila está vazia (para `mensagem_fila`) ou a
calibração ainda não terminou (`exigeCalibracao`).

O tour guiado `simulador` (`assistant_tours.dart`) cobre a tela inteira —
header, abas, KPIs, fila, recomendação, gráfico, cenários, slots, ações de IA
— com âncoras (`HelpAnchors.sim*`) registradas via `AssistantTarget` nos
próprios widgets. O ícone **"?"** no header (`monte_carlo_screen.dart`) chama
`ref.read(assistantProvider.notifier).startTour('simulador')` a qualquer
momento; o assistente também reconhece perguntas livres sobre o simulador via
`assistant_knowledge.dart` (ex.: "o que é P95?", "como funciona o simulador?").

### Testes

| Arquivo | Cobertura |
|---------|-----------|
| `monte_carlo_engine_test.dart` | 18 testes: oráculo exato, convergência do amostrador, preservação das marginais, determinismo, isolamento entre slots, bordas |
| `monte_carlo_avancado_test.dart` | 11 testes: três estados, base de capacidade, modos de encaixe, equidade, fila |
| `monte_carlo_calibracao_test.dart` | 16 testes: métricas distribucionais e **recuperação de parâmetros conhecidos** a partir de histórico sintético |
| `monte_carlo_historico_demo_test.dart` | 18 testes: gerador sintético, recuperação de ponta a ponta, **controles de erro tipo I/poder** do detector de sazonalidade |
| `monte_carlo_persistencia_test.dart` | 8 testes: mapeamento dos documentos, sem Firebase |
| `monte_carlo_acoes_ia_test.dart` | 19 testes: catálogo, `MontadorContexto` (fatos e `numerosPermitidos` corretos), validador aplicado a texto simulado |
| `monte_carlo_executor_acoes_test.dart` | 9 testes: `indisponivel()` em cada pré-condição, uma ação por vez |
| `monte_carlo_screen_test.dart` | 19 testes de widget: 5 abas, ícone de ajuda abre o tour, ícones de gráfico, 3 larguras de viewport |

---

## 📈 Módulo 11 — Projeção de 12 meses (`features/projecao_12m/`)

### Objetivo

Responder a duas perguntas: **o que tende a acontecer se a clínica continuar
como está**, e **o que muda com as intervenções da Agenda Clínica** — com
intervalo honesto, não número pontual.

Complementa o módulo Monte Carlo, que decide **amanhã** por slot. Este projeta
**doze meses** no agregado, para conversa de planejamento e comercial.

### Escopo: o que é código de app e o que é nuvem

A especificação descreve quatro camadas e usa Azure ML para treino, registro e
implantação. **Treino de AutoML, endpoints e pipelines são infraestrutura de
nuvem, não código Flutter** e ficaram fora. O que está implementado é o motor
que roda no app: cadeia de Markov, simulação com incerteza propagada, restrição
de capacidade, decomposição financeira e o portão de aceite do forecast.

### Três decisões de modelagem

| # | Decisão | Por quê |
|---|---------|---------|
| 1 | **Três camadas de incerteza** | Forecast (lognormal com WAPE), parâmetro (Beta com força do histórico) e amostral (multinomial). Propagar só a última produz intervalo rotulado 90% que cobre ~46% dos futuros. |
| 2 | **Sorteio multinomial único** | Falta, cancelamento e comparecimento são mutuamente exclusivos. Sortear falta sobre o total e cancelamento sobre o resíduo faz 10% pedidos virarem 7,8% realizados. |
| 3 | **Capacidade é restrição dura** | Sem teto a simulação projeta mais atendimento do que a agenda comporta — e fica mais otimista justamente onde deveria esbarrar no limite físico. O que não cabe vira lista de espera, reportada à parte. |

### Cadeia de Markov

Sete estados; `reagendado` é estado **próprio**, não cancelamento — reagendar
preserva o paciente e devolve a vaga; cancelar perde as duas coisas.

- Suavização de Dirichlet: sem ela, estado nunca observado vira linha de zeros,
  que não é distribuição e quebra a simulação em silêncio.
- **Não-homogênea**: matriz por faixa de dias até a consulta. A confirmação se
  concentra nas 72 horas finais; aplicar delta uniforme supõe que um lembrete de
  30 dias vale tanto quanto um de 2.
- Shrinkage empírico-bayesiano para partida a frio.
- A matriz de referência reproduz a absorção publicada: 69,0 / 22,1 / 9,0.

### Receita defensável

Vaga reposta por paciente que já seria atendido depois é **antecipação de
demanda**, não receita nova — no horizonte aparece uma vez, não duas. As duas
cifras são reportadas separadas e nunca somadas. No exemplo da spec, somar tudo
superestima em **21,9%**, valor reproduzido em teste.

### Limitações conhecidas

- **Nada é calibrado com dados reais.** Os parâmetros de impacto são hipótese;
  a tela exibe isso de forma destacada e sai só depois do piloto.
- O volume mensal é parâmetro manual, com sugestão a partir da agenda. Não há
  forecast de série temporal implementado — o portão de aceite existe para
  avaliar um, quando houver.
- A cadeia não-homogênea está implementada e testada, mas a projeção usa a
  matriz agregada: falta ligar as faixas ao laço de simulação.
- Sem persistência: nenhuma projeção é gravada, então não há auditoria das
  premissas que produziram um número apresentado.
- Equidade (§8 da spec) e dimensionamento de piloto (§16) não implementados.

### Testes

| Arquivo | Cobertura |
|---------|-----------|
| `projecao_12m_test.dart` | 31 testes: amostradores (lognormal/Beta/multinomial), Markov (absorção publicada, suavização, faixas, shrinkage), três camadas de incerteza, capacidade, receita defensável e portão de aceite |
| `projecao_12m_screen_test.dart` | 7 testes de widget, 3 larguras de viewport |
