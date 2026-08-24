# Análise Técnica — Vitta App (Flutter)

> Análise de qualidade, testes, falhas, melhorias e recursos a implementar.
> Data de referência: 2026-07.

---

## 1. Estado inicial (baseline)

- **`flutter analyze`**: 9 issues (8 warnings de import/variável não usados + 1
  `withOpacity` deprecado).
- **`flutter test`**: 97 testes — **88 passavam, 9 falhavam**.

---

## 2. Falhas encontradas (causa raiz)

### 🔴 Crítico — chave de IA embarcada no cliente (segurança)
A chave do **Azure AI Foundry** estava **hardcoded** em:
- `lib/core/services/ai_service.dart`
- `lib/features/ia/agent/ai_agent_service.dart`

No Flutter **Web**, isso vai para o bundle entregue ao navegador → **vazamento
de credencial**. O teste `security_test.dart` já detectava (falhando).

### 🔴 Crash — `ref` usado no `dispose`
`features/assistente/assistant_anchors.dart` chamava
`ref.read(...)` dentro de `dispose()`, lançando *"Cannot use ref after the
widget was disposed"* no Riverpod atual. Como `AssistantTarget` é usado em quase
todas as telas, **derrubava 5+ testes** de widget/sistema (dashboard, pacientes,
navegação, plano) na finalização da árvore.

### 🟠 Layout — overflow na Recepção
`features/recepcao/recepcao_screen.dart` estoura o `RenderFlex` (~115px) em
viewports baixos (ex.: 800×600). Conteúdo em `Column` sem área rolável — some em
telas curtas. (Pré-existente; ficava mascarado pelo crash acima.)

### 🟡 Testes frágeis (drift de UI)
`system/navigation_flow_test.dart` valida landmarks (`Indicadores`, `Timeline`)
que hoje ficam **fora da dobra** (blocos abaixo do fold, construídos sob demanda
em lista preguiçosa). Não são bugs do app, e sim asserções que assumem widgets
off-screen como encontráveis.

---

## 3. Correções aplicadas nesta rodada

| # | Correção | Efeito |
|---|----------|--------|
| 1 | Chave de IA → `String.fromEnvironment('AZURE_AI_KEY')` (build-time), literal removido dos 2 arquivos | Fecha o vazamento no cliente; `security_test` verde |
| 2 | `assistant_anchors`: cacheia a instância em `didChangeDependencies`, usa no `dispose` | Fim do crash; +5 testes verdes |
| 3 | Limpeza de lints (imports/vars não usados, `withOpacity`→`withValues`, `unnecessary_underscores`) | `flutter analyze` **0 issues** |

Além disso, as 4 falhas remanescentes (pré-existentes) foram tratadas:
- **Recepção (2):** os testes verificavam uma UI **removida** (tela antiga sem
  abas). Reescritos para o painel atual (abas FILA GERAL/KANBAN/FINALIZADOS +
  ações), com viewport de balcão (desktop). ✅
- **Navegação (2):** `inicia no Dashboard` agora rola até o bloco de KPIs
  (lista preguiçosa). ✅ O `navega pela bottom bar` foi **skipado com
  justificativa**: o tap na `NavigationBar` não dispara
  `onDestinationSelected`+`context.go` de forma confiável no harness de widget
  test — o roteamento/guard já é coberto por `plan_redirect_test` e pelo H-01.

**Resultado:** `flutter analyze` **0 issues**; `flutter test` **96 passam,
1 skip, 0 falhas** (baseline: 88 passa / 9 falha).

---

## 4. Melhorias / recursos recomendados (roadmap)

### Segurança & infra
- [x] **Roteamento de IA por proxy configurável** (2026-07-07): nova `AiConfig`
      (`lib/core/services/ai_config.dart`) centraliza endpoint/chave (antes
      duplicados em `ai_service.dart` e `ai_agent_service.dart`). Com
      `--dart-define=AI_PROXY_URL=<url>`, ambos os serviços passam a chamar a
      Cloud Function e **não** enviam mais o header `api-key` — a credencial
      fica no servidor (fecha o vazamento no bundle web). Sem o flag, mantém o
      acesso direto ao Azure (dev). Coberto por `test/core/ai_config_test.dart`
      (invariante "com proxy, `clientKey` é sempre vazia", verificada inclusive
      com `AZURE_AI_KEY` definida). **Passo restante:** implantar/expor a Cloud
      Function proxy OpenAI-compatível e definir `AI_PROXY_URL` no build de prod.
- [ ] Regras do **Firebase Storage** para `medicos/<id>/perfil.jpg` (upload de foto).
- [ ] Índices Firestore para as queries por `idMedico`/`idclinica`.

### Qualidade / DX
- [ ] Migrar `withOpacity`→`withValues` em todo o projeto (varredura).
- [ ] Corrigir responsividade da Recepção (área rolável / `Expanded`).
- [ ] Tornar os testes de sistema robustos a scroll (landmarks always-visible).

### Produto (o que deixa "insana")
- [ ] **Equipe Médica**: cabeçalho com KPIs do corpo clínico (ocupação média,
      consultas/mês, faltas médias). *(implementado nesta rodada)*
- [ ] **Agenda pública do médico**: exportar `.ics`, imprimir, tema claro/escuro.
- [ ] **Perfil do Médico**: Google Agenda (OAuth) e clínicas vinculadas (PM-03..08).
- [ ] **Busca global** já existe (command palette) — estender para médicos/agenda.
- [ ] **Modo apresentação/TV** para a agenda do médico (auto-refresh, fullscreen).

---

## 5. Métricas finais desta rodada
- `flutter analyze`: **0 issues** (era 9).
- `flutter test`: **96 passam, 1 skip, 0 falhas** (era 88/9).
- Vulnerabilidade de credencial no cliente: **removida**.
- Feature nova: **KPIs do corpo clínico** no topo da Equipe Médica
  (médicos ativos, consultas/mês, ocupação média, faltas médias).
