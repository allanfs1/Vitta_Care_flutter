# ✅ TASKS — Vitta App

> Status de implementação dos módulos definidos em `.specify/AGENTS.md`.
> Stack: Flutter • Riverpod • GoRouter • fl_chart • google_fonts (Inter).
> Multiplataforma: mobile (app) + desktop/web **PWA**.
>
> Legenda: ✅ concluído • ❌ não concluído (pendente)

---

## 🧱 Base (Design System + Navegação)

| Item | Status | Onde |
|------|:------:|------|
| Design System (cores, tipografia, espaçamentos, tema claro/escuro) | ✅ | `lib/core/theme/` |
| Modelos compartilhados (clínica, médico, paciente, consulta, usuário) | ✅ | `lib/core/models/` |
| Serviços compartilhados + Riverpod (estado global, seleção de clínica) | ✅ | `lib/core/services/` |
| Widgets reutilizáveis (cards, badges, KPIs, gráficos, avatar, header) | ✅ | `lib/core/widgets/` |
| Roteamento centralizado (GoRouter) + deep linking | ✅ | `lib/navigation/app_router.dart` |
| Shell responsivo (bottom nav mobile / nav rail desktop) | ✅ | `lib/navigation/app_shell.dart` |
| Drawer lateral global | ✅ | `lib/navigation/drawer/` |
| PWA (manifest + service worker para abrir no desktop) | ✅ | `web/manifest.json`, `web/index.html` |

---

## 🧑‍💼 Agente 1 — Dashboard Home (`features/home/`)

| ID | Funcionalidade | Status |
|----|----------------|:------:|
| H-01 | Seletor de clínica (persistente) | ✅ |
| H-02 | Perfil da unidade (UBS/UPA/APS/Privada) | ✅ |
| H-03 | Calendário/seletor da semana com indicadores | ✅ |
| H-04 | Gráficos em tempo real (tendência, absenteísmo) | ✅ |
| H-05 | KPIs principais (6 cards) | ✅ |
| H-06 | Barra de atalhos superiores | ✅ |

> Observação: gráficos atualizam por dados mock; WebSocket/tempo-real real depende do Firebase (❌ backend pendente).

## 📅 Agente 2 — Agendamentos (`features/agendamentos/`)

| ID | Funcionalidade | Status |
|----|----------------|:------:|
| A-01 | Lista com filtros (data, médico, status, especialidade) | ✅ |
| A-02 | Detalhamento completo da consulta | ✅ |
| A-03 | Ações (confirmar/cancelar/reagendar) com modal | ✅ |
| A-04 | Timeline diária do médico | ✅ |

## 📊 Agente 3 — Absenteísmo (`features/absenteismo/`)

| ID | Funcionalidade | Status |
|----|----------------|:------:|
| AB-01 | Dashboard de absenteísmo (pizza/barras/linha) | ✅ |
| AB-02 | Dashboard de cancelamentos | ✅ |
| AB-03 | Calendário analítico | ⚠️ parcial (KPIs + heatmap; calendário mês/semana/dia ❌) |
| AB-04 | Gráficos de densidade (heatmap) | ✅ |
| AB-05 | KPIs e métricas-chave | ✅ |
| AB-06 | Risco de faltas (IA) | ✅ |
| AB-07 | Relatórios inteligentes | ✅ |
| AB-08 | Relatório por especialidade | ✅ |
| AB-09 | Relatório por médico | ⚠️ parcial (KPI "maior risco por médico"; detalhamento individual ❌) |

## 🧠 Agente 4 — Inteligência Artificial (`features/ia/`)

| ID | Funcionalidade | Status |
|----|----------------|:------:|
| IA-01 | Agendamento inteligente B2B (gated por tipo de clínica) | ✅ |
| IA-02 | Análise de dados | ✅ |
| IA-03 | Geração de relatórios | ✅ |
| IA-04 | Criação de dashboards por prompt | ✅ (UI; geração real ❌ pendente backend) |

> IA conectada via stub do **Azure AI Foundry / DeepSeek V4** (`AiService`). Integração real exige Cloud Function intermediária (❌).

## 👤 Agente 5 — Perfil do Usuário (`features/perfil_usuario/`)

| ID | Funcionalidade | Status |
|----|----------------|:------:|
| PU-01 | Foto de perfil | ✅ (UI; upload real ❌) |
| PU-02 | Dados pessoais | ✅ |
| PU-03 | Contato | ✅ |
| PU-04 | Endereço com busca por CEP | ✅ (busca simulada) |
| PU-05 | Segurança (alterar senha) | ✅ |

## 🏥 Agente 6 — Perfil da Clínica (`features/perfil_clinica/`)

| ID | Funcionalidade | Status |
|----|----------------|:------:|
| PC-01 | Dados da clínica | ✅ |
| PC-02 | Endereço da clínica | ⚠️ parcial (formulário base; CEP automático ❌) |
| PC-03 | Contato | ✅ |
| PC-04 | Logotipo | ✅ (UI; upload real ❌) |
| PC-05 | Horário de funcionamento | ✅ |
| PC-06 | Especialidades | ✅ |

## 💬 Agente 7 — WhatsApp (`features/whatsapp/`)

| ID | Funcionalidade | Status |
|----|----------------|:------:|
| WA-01 | Conexão por QR Code | ✅ (UI + fluxo simulado) |
| WA-02 | Status da conexão | ✅ |
| WA-03 | Logs de mensagens | ✅ |
| WA-04 | Configurações do assistente | ✅ |

> Integração **Z-API** via stub (`WhatsappService`). Pareamento real e envio exigem credenciais em `tb_config_whatsapp` (❌).

## 🔐 Agente 9 — Autenticação e Planos (`features/auth/`)

| ID | Funcionalidade | Status |
|----|----------------|:------:|
| AU-01 | Login (Firebase Auth e-mail/senha) | ✅ |
| AU-02 | Criar conta (Firebase) | ✅ |
| AU-03 | Recuperar senha (e-mail Firebase) | ✅ |
| AU-04 | Escolher plano (mensal/anual, `tb_plans`) | ✅ |
| AU-05 | Sessão reativa + logout | ✅ |

> **Firebase Authentication ligado** via `FirebaseAuthService` + `firebase_options.dart`
> (config do projeto `agendaclinica-457713`). Fallback automático para mock se o
> Firebase não inicializar. Persistência do plano em `tb_plan_user` real: ❌ pendente.

## 🗺️ Sistema de Módulos — Mapa de Dependências (`core/modules/`)

| Item | Status |
|------|:------:|
| Modelo `AppModule` (prioridade, status, deps, coleções) | ✅ |
| `ModuleRegistry` (15 módulos, arestas do diagrama) | ✅ |
| Grafo: ordem topológica, detecção de ciclos, validação | ✅ |
| Isolamento: coleções `owned` disjuntas (validado em teste) | ✅ |
| Tela "Mapa de Módulos" (`/arquitetura`) | ✅ |
| Testes do grafo (`test/unit/module_graph_test.dart`) | ✅ |

> Módulos do mapa ainda **planejados** (registrados no sistema, UI a construir):
> Recepção ❌, Tickets ❌, Financeiro ❌, Previsão de Faltas ⚠️ (parcial no Absenteísmo),
> Integrações/Google Agenda ⚠️.

## 🧭 Agente 8 — Navegação (`navigation/`)

| ID | Funcionalidade | Status |
|----|----------------|:------:|
| NAV-01 | Roteamento (GoRouter) | ✅ |
| NAV-02 | Drawer lateral | ✅ |
| NAV-03 | Bottom Navigation | ✅ |
| NAV-04 | Deep linking | ✅ |

---

## ❌ Pendências (dependem de credenciais/backend reais)

- ❌ Integração real com **Firebase/Firestore** (coleções de `database.md`) — hoje há mock fiel à estrutura.
- ❌ Chamadas reais ao **Azure AI Foundry** (via Cloud Function — a chave não deve ficar no cliente).
- ❌ Pareamento/envio real via **Z-API**.
- ❌ Upload real de imagens (foto de perfil / logotipo).
- ✅ Autenticação via **Firebase Auth** (login, cadastro, recuperação de senha) — ligada.
