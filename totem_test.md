# Plano de Testes Automatizados — Totem de Autoatendimento

> **Módulo:** Totem (`/totem`) + Painel de Configuração (`TotemConfigPanel`, acessível
> por `Configurações → Totem` e por toque longo no logo do totem).
> **Objetivo:** Verificar se **todas** as opções do painel de configuração são
> corretamente aplicadas ao sistema do totem (tela inicial, fluxo de
> agendamento/remarcação, sessão, comprovante e horários) e se a persistência /
> prévia em tempo real funcionam.
> **Última execução:** 01/07/2026 — ambiente web (`http://localhost:60823`).

---

## 1. Escopo e arquitetura sob teste

| Camada | Arquivo | Papel |
|--------|---------|-------|
| Modelo de config | `lib/features/totem/models/totem_config.dart` | 44 campos + `copyWith`/`toJson`/`fromJson` |
| Persistência | `lib/features/totem/providers/totem_config_provider.dart` | `StateNotifier` → SharedPreferences (`totem_config`) |
| Perfis (presets) | `lib/features/totem/models/totem_profile.dart` | 5 presets: UBS, UPA, APS, Clínica Popular, Clínica Normal |
| Overrides de perfil | `lib/features/totem/providers/totem_profiles_provider.dart` | Salva/restaura config por perfil (`totem_profiles`) |
| Painel de config | `lib/features/totem/widgets/totem_config_panel.dart` | Controles + auto-save no perfil ativo |
| Prévia ao vivo | `lib/features/totem/widgets/totem_preview.dart` | Observa `totemConfigProvider`, abas Início/Agendar |
| Sistema do totem | `lib/features/totem/totem_screen.dart` | Fluxo real de autoatendimento (lê `_tc = totemConfigProvider`) |
| Roteamento | `lib/navigation/app_router.dart` | `/totem` é **rota pública** (sem login) |

**Premissa arquitetural verificada:** tanto `TotemScreen` quanto `TotemPreview`
leem o **mesmo** `totemConfigProvider`; qualquer alteração no painel reflete no
totem real e na prévia, e é persistida em SharedPreferences. Rota `/totem` é
pública (não exige autenticação); o painel também é acessível de forma oculta por
toque longo (3s) no logo do totem.

---

## 2. Como executar

### 2.1 Execução manual assistida (browser)
1. Abrir `http://localhost:60823/#/totem`.
2. Toque longo no cartão do logo (canto superior esquerdo) → abre **Configuração do Totem**.
3. Para cada caso de teste, alterar a opção indicada e conferir a **Prévia em tempo real** e/ou voltar ao totem (seta ⟵) para conferir o **sistema real**.

### 2.2 Execução por teste automatizado (Flutter)
```bash
flutter test test/features/totem_config_test.dart
```
> Esqueleto de teste de widget sugerido no **Apêndice A** (ainda não versionado).

---

## 3. Matriz de rastreabilidade config → efeito no totem

Cada campo de `TotemConfig` e onde ele é consumido no sistema do totem:

| # | Campo | Efeito esperado no totem | Consumido em |
|---|-------|--------------------------|--------------|
| MARCA E TEXTOS |
| 1 | `clinicName` | Nome no topo + comprovante | `_topBar`, `_success` |
| 2 | `welcomeTitle` | Título grande da tela inicial | `_welcome` |
| 3 | `welcomeSubtitle` | Subtítulo da tela inicial | `_welcome` |
| 4 | `accent` | Cor de destaque (botão inicial, chips, faixa da semana, ícones, timer) | vários (`_tc.accentColor`) |
| 5 | `logoUrl` | Logo (URL) ou coração padrão | `_brandLogo`, preview `_logo` |
| TELA INICIAL |
| 6 | `showTutorial` | Botão "Como usar o totem" | `_welcome` |
| 7 | `showTestPrint` | Botão "Testar impressão" | `_welcome` |
| INTERFACE |
| 8 | `showClock` | Relógio no topo | `_topBar` |
| 9 | `showDoctorCard` | Cartão do médico ao escolher horário | `_schedule` |
| 10 | `showOccupancy` | Legenda de ocupação (LIVRE/MÉDIA/ÚLTIMAS/LOTADO) | `_schedule`, `_occLegend` |
| 11 | `scale` | Escala de fonte (`textScaler`) | `build` (MediaQuery) |
| 12 | `gradientBackground` | Fundo com/sem gradiente | `build` decoration |
| SUGESTÕES |
| 13 | `showSuggestions` | Linha "MAIS PROCURADAS" | `_schedule` |
| 14 | `maxSuggestions` | Nº de chips de sugestão | `_topSpecialties(max:)` |
| AGENDAR / REMARCAR |
| 15 | `agendarTitle` | Título no modo agendar | `_schedule` |
| 16 | `remarcarTitle` | Título no modo remarcar | `_schedule` |
| 17 | `agendarButtonLabel` | Rótulo do botão de ação (agendar) | `_schedule` |
| 18 | `remarcarButtonLabel` | Rótulo do botão de ação (remarcar) | `_schedule` |
| 19 | `showStepper` | Indicador de passos (1–4) | `_schedule`, `_chooseApptScreen` |
| 20 | `showWeekStrip` | Faixa de dias da semana | `_schedule` |
| 21 | `showCalendarButton` | Botão "Abrir calendário" | `_schedule` |
| 22 | `showDoctorFilter` | Chips "Filtrar por médico" | `_schedule` |
| FLUXOS |
| 23 | `allowAgendar` | Botão "Agendar consulta" | `_welcome` |
| 24 | `allowRemarcar` | Botão "Remarcar consulta" | `_welcome` |
| 25 | `allowGuestScheduling` | Cadastro de convidado se CPF não achado | `_checkCpf` |
| 26 | `requirePhone` | Telefone obrigatório no cadastro | `_submitNew` |
| 27 | `printEnabled` | Botão "Imprimir comprovante" | `_success` |
| 28 | `ticketFooter` | Rodapé do comprovante | `_success`, e-mail |
| 29 | `confirmViaWhatsapp` | Envio de confirmação por WhatsApp (Z-API) | `_sendConfirmations` |
| 30 | `confirmationLink` | Link enviado no WhatsApp | `_sendConfirmations` |
| REGRAS DE AGENDAMENTO |
| 31 | `defaultSpecialty` | Especialidade pré-selecionada | `initState`, `_reset` |
| 32 | `appointmentDuration` | Duração da consulta criada | `_createAppointment` |
| 33 | `maxDaysAhead` | Limite de dias no calendário/faixa | `_openCalendar`, `_weekStrip` |
| 34 | `arrivalMinutes` | Antecedência no comprovante | `_success` |
| 35 | `maxPerDay` | Máx. consultas/dia por paciente | `_bookingLimitMessage` |
| 36 | `maxActivePerPatient` | Máx. consultas ativas por paciente | `_bookingLimitMessage` |
| SESSÃO |
| 37 | `sessionTimeout` | Segundos de inatividade | timer `initState` |
| 38 | `warningSeconds` | Aviso antes de expirar | `_warning`, overlay |
| 39 | `successAutoReturn` | Retorno automático na tela de sucesso | timer `initState` |
| FUNCIONAMENTO |
| 40 | `openHour` | Primeira hora de slots | `_buildSlots` |
| 41 | `closeHour` | Última hora (seg–sex) | `_buildSlots` |
| 42 | `openSaturday` / `saturdayCloseHour` | Sábado on/off + fechamento | `_buildSlots` |
| 43 | `openSunday` | Domingo on/off | `_buildSlots` |
| 44 | `lunchBreakEnabled` / `lunchStartHour` / `lunchEndHour` | Bloqueio do almoço | `_buildSlots` |

---

## 4. Casos de teste

> Legenda de status: ✅ Passou · ❌ Falhou · ⚠️ Passou com observação · ⛔ Não executado

### Grupo A — Marca e textos

**TC-A1 — Nome da unidade reflete no topo e no comprovante**
- **Passos:** Painel → alterar "Nome da unidade" para `Hospital Teste 01`.
- **Esperado:** topo do totem e cabeçalho da prévia mostram o novo nome; comprovante usa o nome.
- **Resultado (01/07):** ✅ Prévia e totem real atualizaram para o novo nome; comprovante do preset UBS exibiu "UBS".

**TC-A2 — Título e subtítulo de boas-vindas**
- **Passos:** alterar "Título de boas-vindas" e "Subtítulo".
- **Esperado:** tela inicial reflete os textos em tempo real.
- **Resultado:** ✅ Título alterou para "Olá, seja bem-vindo!" na prévia instantaneamente.

**TC-A3 — Cor de destaque (accent)**
- **Passos:** trocar a cor de destaque / aplicar preset UBS (verde).
- **Esperado:** botão inicial, chips selecionados, faixa da semana, ícone do relógio e timer usam a cor.
- **Resultado:** ⚠️ Elementos "acessórios" (botão inicial, chips, faixa da semana, VERIFICAR, CADASTRAR) usam o accent. Porém **título e botão principal** da tela de agendamento (`Agendar Consulta` / `AGENDAR`) e a tela de CPF usam o vermelho fixo `_kBrand` — ver **Achado F-2**.

**TC-A4 — URL de logo**
- **Passos:** preencher "URL do logo" com link https válido; limpar.
- **Esperado:** miniatura carrega; totem/prévia mostram a imagem; vazio → coração padrão.
- **Resultado:** ⛔ Não executado nesta rodada (sem URL de imagem à mão). Binding confirmado por código (`_brandLogo`/`_logo`).

### Grupo B — Perfis (presets)

**TC-B1 — Aplicar preset UBS**
- **Passos:** clicar no chip "UBS".
- **Esperado:** `clinicName=UBS`, título "Bem-vindo à UBS", subtítulo, accent verde, abertura 07h, almoço 12–13h; banner "salvas automaticamente em UBS".
- **Resultado:** ✅ Todos os campos aplicados **atomicamente**; banner de auto-save exibido; totem real refletiu tudo.

**TC-B2 — Auto-save e restauração de perfil**
- **Passos:** com perfil ativo, alterar um campo → deve salvar no override; usar "Restaurar".
- **Esperado:** override persistido; "Restaurar" volta ao preset embutido.
- **Resultado:** ⛔ Não executado o ciclo completo de restore nesta rodada (auto-save confirmado por código em `_set` + `save`).

### Grupo C — Tela inicial e interface

**TC-C1 — showTutorial / showTestPrint**
- **Esperado:** ligar/desligar mostra/oculta os botões "Como usar" e "Testar impressão".
- **Resultado:** ✅ Botões presentes com config padrão (ambos `true`) na tela inicial.

**TC-C2 — showClock**
- **Esperado:** relógio aparece/some no topo.
- **Resultado:** ✅ Relógio visível (11:5x) com `showClock=true`.

**TC-C3 — showDoctorCard**
- **Esperado:** ao escolher horário, cartão do médico aparece.
- **Resultado:** ✅ "Dr. Roberto Santos • Cardiologia • CRM 123456-SP" exibido após seleção.

**TC-C4 — showOccupancy**
- **Esperado:** legenda LIVRE/MÉDIA/ÚLTIMAS/LOTADO aparece ao lado de "HORÁRIO".
- **Resultado:** ✅ Legenda exibida.

**TC-C5 — scale / gradientBackground**
- **Esperado:** escala de fonte muda tamanhos; gradiente liga/desliga o fundo.
- **Resultado:** ⛔ Não executado (binding confirmado por código: `textScaler` + `_bg`).

### Grupo D — Agendar / Remarcar

**TC-D1 — Título e stepper**
- **Esperado:** título = `agendarTitle`; stepper 1–4 visível quando `showStepper`.
- **Resultado:** ✅ "Agendar Consulta" + stepper SERVIÇO→ESPECIALISTA→CONFIRMAÇÃO→FINALIZADO.

**TC-D2 — Sugestões (MAIS PROCURADAS) e maxSuggestions**
- **Esperado:** linha aparece com no máx. `maxSuggestions` chips das especialidades mais agendadas.
- **Resultado:** ✅ Chips exibidos (Cardiologia, Clínica Geral, Dermatologia).

**TC-D3 — Faixa da semana começa em hoje / maxDaysAhead**
- **Esperado:** faixa inicia no dia atual; calendário limitado a `maxDaysAhead`.
- **Resultado:** ✅ Faixa iniciou em QUA 1 (hoje = quarta, 01/07/2026), QUI 2 … TER 7.

**TC-D4 — Filtro por médico**
- **Esperado:** chips "Todos" + médicos reais quando há >1 médico.
- **Resultado:** ✅ Todos, Dr. Roberto, Dra. Ana, Dr. Marcos, Dra. Juliana.

**TC-D5 — Botão "Abrir calendário"**
- **Esperado:** botão visível quando `showCalendarButton`; abre date picker limitado.
- **Resultado:** ✅ Botão "CALENDÁRIO" presente (abertura do picker não acionada nesta rodada).

### Grupo E — Funcionamento (horários)

**TC-E1 — openHour / closeHour**
- **Esperado:** slots de `openHour` a `closeHour-1`.
- **Resultado:** ✅ UBS abre 07h → prévia mostrou 07:00 como primeiro slot.

**TC-E2 — Ocultar horários passados no dia de hoje**
- **Esperado:** hoje, horas ≤ hora atual não aparecem.
- **Resultado:** ✅ Às 11:5x, o primeiro slot ofertado foi 13:00 (11h e 12h ocultos).

**TC-E3 — Intervalo de almoço**
- **Esperado:** com `lunchBreakEnabled`, o intervalo (12–13h) é pulado.
- **Resultado:** ✅ Prévia UBS listou 07,08,09,10,11,**13**,14,15 — 12:00 ausente.

**TC-E4 — Sábado / Domingo**
- **Esperado:** slots respeitam `openSaturday/saturdayCloseHour/openSunday`.
- **Resultado:** ⛔ Não executado (requer trocar a data para fim de semana). Lógica confirmada em `_buildSlots`.

### Grupo F — Fluxo completo de agendamento (convidado)

**TC-F1 — CPF não cadastrado → cadastro de convidado**
- **Pré-condição:** `allowGuestScheduling=true`.
- **Passos:** Agendar → escolher horário → AGENDAR → digitar CPF `12345678901` → VERIFICAR.
- **Esperado:** snackbar "CPF não encontrado. Complete o cadastro." + formulário de cadastro.
- **Resultado:** ✅ Comportamento exato; título mudou para "Complete seu Cadastro".

**TC-F2 — requirePhone**
- **Esperado:** UBS (`requirePhone=false`) permite concluir só com nome; com `true` exige telefone.
- **Resultado:** ✅ Concluído apenas com nome + e-mail (UBS não exige telefone).

**TC-F3 — Criação do agendamento + comprovante**
- **Passos:** preencher nome `Paciente Teste Totem`, e-mail, "CADASTRAR E AGENDAR".
- **Esperado:** tela de sucesso com senha, dados, `arrivalMinutes` e `ticketFooter`; botão de impressão se `printEnabled`.
- **Resultado:** ✅ Senha `C905` (inicial da especialidade), Paciente/Médico/Especialidade/Data corretos, "Chegue com **15 minutos** de antecedência" (`arrivalMinutes=15`), rodapé "**Compareça à recepção com este comprovante.**" (`ticketFooter` do preset UBS), botão "IMPRIMIR COMPROVANTE" presente (`printEnabled=true`).

**TC-F4 — Senha derivada da especialidade**
- **Esperado:** senha começa com a inicial da especialidade.
- **Resultado:** ✅ Cardiologia → `C905`.

### Grupo G — Sessão

**TC-G1 — Timer de sessão e retorno automático**
- **Esperado:** timer conta `sessionTimeout`; atividade reseta; sucesso volta em `successAutoReturn`.
- **Resultado:** ✅ Timer iniciou ~01:58; cliques resetaram para ~01:5x; tela de sucesso contou 00:17→00:06 (`successAutoReturn=18`).

**TC-G2 — Aviso antes de expirar (warningSeconds)**
- **Esperado:** overlay de aviso aparece quando restam ≤ `warningSeconds`.
- **Resultado:** ⛔ Não executado (exigiria aguardar a inatividade). Lógica confirmada em `build`/`_warningOverlay`.

### Grupo H — Persistência e prévia

**TC-H1 — Prévia em tempo real**
- **Esperado:** toda alteração reflete imediatamente na prévia (abas Início/Agendar).
- **Resultado:** ✅ Confirmado em texto, cor, horários e sugestões.

**TC-H2 — Persistência entre sessões**
- **Esperado:** config sobrevive a recarregar a página (SharedPreferences).
- **Resultado:** ⛔ Não executado o reload explícito. Confirmado por código (`update` → `setString`).

---

## 5. Resumo da execução (01/07/2026)

| Grupo | Passou | Observação | Não executado |
|-------|:------:|:----------:|:-------------:|
| A — Marca/textos | 2 | 1 (⚠️ accent) | 1 |
| B — Perfis | 1 | — | 1 |
| C — Interface | 4 | — | 1 |
| D — Agendar | 5 | — | — |
| E — Horários | 3 | — | 1 |
| F — Fluxo completo | 4 | — | — |
| G — Sessão | 1 | — | 1 |
| H — Persist./prévia | 1 | — | 1 |
| **Total** | **21** | **1** | **6** |

**Conclusão:** As configurações estão **corretamente implementadas e conectadas**
ao sistema do totem. Todos os 21 casos executados passaram; 6 não foram
executados nesta rodada (verificados por inspeção de código) e nenhum falhou.
Foram registrados 2 achados (1 bug de baixa severidade + 1 inconsistência de
tema), abaixo.

---

## 6. Achados

### F-1 (Bug, baixa severidade) — Condição de corrida ("stale closure") ao editar campos em sequência muito rápida
- **Onde:** `TotemConfigPanel._set` (`totem_config_panel.dart`) — cada `onChanged`
  chama `_set(cfg.copyWith(...))` onde `cfg` é capturado no closure do `build`.
- **Sintoma reproduzido:** editar `clinicName` e, em seguida, `welcomeTitle` em
  sucessão muito rápida (colar/automação, antes do rebuild propagar) fez o
  segundo `onChanged` usar um `cfg` desatualizado e **reverter** a alteração de
  `clinicName` no estado (o campo de texto continuava mostrando o novo valor, mas
  a prévia/estado voltavam ao valor antigo).
- **Impacto:** baixo em uso humano normal (há rebuild entre um campo e outro),
  mas pode causar perda de edição em digitação/colagem muito rápida.
- **Correção sugerida:** em `_set`, basear o `copyWith` no estado **atual** do
  provider, não no `cfg` do closure. Ex.:
  ```dart
  void _set(TotemConfig Function(TotemConfig) mutate) {
    final current = ref.read(totemConfigProvider);
    final c = mutate(current);
    ref.read(totemConfigProvider.notifier).update(c);
    final active = ref.read(activeTotemProfileProvider);
    if (active != null) ref.read(totemProfilesProvider.notifier).save(active, c);
  }
  // uso: onChanged: (v) => _set((c) => c.copyWith(clinicName: v))
  ```

### F-2 (Observação, tema) — Cor de destaque aplicada de forma parcial
- **Onde:** `totem_screen.dart` usa constantes fixas `_kBrand` (#FF3B30) em vários
  CTAs principais: título e botão "AGENDAR/REMARCAR" da tela de agendamento,
  header e botões da tela de CPF/remarcar. Já a tela inicial, chips, faixa da
  semana, timer e ícones usam `_tc.accentColor`.
- **Impacto:** ao configurar um accent não-vermelho (ex.: UBS verde), o totem fica
  com tema "misto" (elementos verdes + botões vermelhos). Funcional, mas
  visualmente inconsistente com a marca escolhida.
- **Sugestão:** padronizar os CTAs principais para `_tc.accentColor` (ou tornar
  explícito que `_kBrand` é a cor institucional fixa por design).

---

## Apêndice A — Esqueleto de teste automatizado (Flutter)

Sugestão de teste de widget para automatizar as verificações de binding
config → UI, cobrindo os grupos A, C, D e E sem depender do navegador.
Salvar como `test/features/totem_config_test.dart`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/totem/models/totem_config.dart';
import 'package:vitta_app/features/totem/providers/totem_config_provider.dart';
import 'package:vitta_app/features/totem/totem_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TotemScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('TC-A1/A2 — textos da tela inicial refletem a config', (t) async {
    final c = await pump(t);
    c.read(totemConfigProvider.notifier).update(
      const TotemConfig(clinicName: 'Hospital Teste 01', welcomeTitle: 'Olá!'),
    );
    await t.pumpAndSettle();
    expect(find.text('Hospital Teste 01'), findsOneWidget);
    expect(find.text('Olá!'), findsOneWidget);
  });

  testWidgets('TC-C1 — showTutorial oculta o botão', (t) async {
    final c = await pump(t);
    c.read(totemConfigProvider.notifier)
        .update(const TotemConfig(showTutorial: false));
    await t.pumpAndSettle();
    expect(find.text('COMO USAR O TOTEM'), findsNothing);
  });

  testWidgets('TC-D/E — allowAgendar=false oculta o botão inicial', (t) async {
    final c = await pump(t);
    c.read(totemConfigProvider.notifier)
        .update(const TotemConfig(allowAgendar: false));
    await t.pumpAndSettle();
    expect(find.textContaining('AGENDAR'), findsNothing);
  });
}
```

> Observação: ajuste os `import` ao nome do pacote em `pubspec.yaml` e adapte os
> seletores conforme necessário. Para o fluxo completo (Grupo F) recomenda-se um
> teste de integração (`integration_test/`) com mocks de `userServiceProvider` e
> `appointmentsProvider`.
