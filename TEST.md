# 🧪 TEST — Estratégia de Testes Automatizados (Vitta App)

> Plano de testes para execução por **AGENTS TEAMS em paralelo**.
> Cada agente é responsável por **uma trilha de testes isolada** e pode rodar
> de forma independente. Stack de teste: `flutter_test`, `ProviderContainer`
> (Riverpod) e mocks de `SharedPreferences`.

---

## ▶️ Como executar

```bash
flutter pub get
flutter analyze                 # análise estática (lint) — gate de qualidade
flutter test                    # toda a suíte
flutter test --coverage         # com cobertura (gera coverage/lcov.info)

# Por trilha (execução paralela por agente):
flutter test test/unit          # Agente T1
flutter test test/widget        # Agente T2
flutter test test/system        # Agente T3
flutter test test/security      # Agente T4
```

> Os testes de sistema forçam tela de celular (390×844) para validar o layout
> mobile (bottom navigation). Não usam rede — `google_fonts` cai no fallback.

---

## 🤖 Regras para os Agentes de Teste

1. Cada agente trabalha **somente na sua pasta** (`test/<trilha>/`).
2. Nenhum teste pode depender de rede, Firebase real, Z-API real ou Azure real
   — tudo via mocks (`MockData`, serviços stub, `SharedPreferences` mock).
3. Testes devem ser **determinísticos** (sem `DateTime.now()` em asserts de igualdade).
4. Antes de finalizar, o agente roda `flutter analyze` + sua trilha e garante verde.
5. Defeitos de UI encontrados (ex.: overflow) devem ser **corrigidos no código de produção**, não silenciados no teste.

---

## 👥 Trilhas (Agentes em paralelo)

### 🧩 Agente T1 — Testes Unitários (`test/unit/`) ✅
Lógica pura e estado, sem árvore de widgets.

| Arquivo | Cobre | Status |
|---------|-------|:------:|
| `validators_test.dart` | E-mail, CPF (dígitos verif.), CEP, CNPJ, senha forte | ✅ |
| `formatters_test.dart` | Datas/hora pt-BR, percentuais, duração, máscara CPF | ✅ |
| `enums_test.dart` | Regras de domínio (B2B, status, faixas de risco) | ✅ |
| `models_test.dart` | `copyWith`, derivações (`end`, `initials`, `formatted`) | ✅ |
| `providers_test.dart` | Seleção/persistência de clínica (H-01), mutações de consulta (A-03) | ✅ |

### 🎨 Agente T2 — Testes de Widget / Componentes (`test/widget/`) ✅
Renderização e regras de negócio na UI isolada.

| Arquivo | Cobre | Status |
|---------|-------|:------:|
| `components_test.dart` | `StatusBadge`, `KpiCard`, `AppAvatar` | ✅ |
| `ia_gating_test.dart` | Regra IA-01 (agendamento inteligente só B2B) | ✅ |

### 🧭 Agente T3 — Testes de Sistema / Usuário (E2E) (`test/system/`) ✅
Fluxos ponta-a-ponta com o app completo (aceitação de usuário).

| Arquivo | Cobre | Status |
|---------|-------|:------:|
| `navigation_flow_test.dart` | Boot no Dashboard; navegação por abas (NAV-03); abertura do seletor de clínica (H-01) | ✅ |
| `widget_test.dart` (raiz) | Smoke test: app builda e mostra o dashboard | ✅ |

### 🔐 Agente T4 — Testes de Segurança (`test/security/`) ✅
Política de credenciais, integridade de entrada e ausência de segredos.

| Arquivo | Cobre | Status |
|---------|-------|:------:|
| `security_test.dart` | Política de senha forte; rejeição de CPF forjado; **nenhum segredo (chave Azure/token Z-API) embarcado em `lib/`** | ✅ |

---

## 🗺️ Rastreabilidade (Funcionalidade → Teste)

| Requisito (AGENTS.md) | Teste |
|-----------------------|-------|
| H-01 seleção de clínica | `providers_test`, `navigation_flow_test` |
| A-03 ações da consulta | `providers_test` (set status / reschedule) |
| IA-01 B2B gating | `enums_test`, `ia_gating_test`, `providers_test` |
| PU-02/PU-05 validações | `validators_test`, `security_test` |
| NAV-01/03 roteamento | `navigation_flow_test` |
| Design System (badges/KPIs) | `components_test` |
| Segurança de credenciais | `security_test` |

---

## 🧱 Pendências / Próximas trilhas (❌ a implementar)

- ❌ **Testes de integração** com `integration_test/` rodando em device/emulador
  (gestos reais, performance de scroll, fl_chart em tela real).
- ❌ **Golden tests** (snapshots visuais) para comparar telas com os mockups de `.specify/Designer/`.
- ❌ **Contract tests** dos serviços Firebase/Z-API/Azure quando as integrações reais forem ligadas (hoje são stubs).
- ❌ **Testes de acessibilidade** (`meetsGuideline`, contraste, tamanho de toque).
- ❌ **Cobertura mínima** configurada em CI (gate, ex.: ≥ 80%).

---

## 📊 Status atual

```
flutter analyze  → No issues found
flutter test     → 44 testes • 100% verde
```
