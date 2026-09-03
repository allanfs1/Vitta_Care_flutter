# 📐 Requisitos de Teste — Integridade do Totem de Autoatendimento

> **Objetivo:** verificar a integridade do sistema do totem **simulando uma aplicação real** — várias pessoas usando o totem ao mesmo tempo — e comprovar que as correções dos achados **F1–F8** (ver `Relatorio_Teste_Totem_10_Agendamentos.md`) se sustentam sob concorrência.
>
> **Forma de verificação:** suíte automatizada `flutter test` — `test/features/totem_integridade_test.dart`. O ambiente de browser está fora do ar; a simulação de concorrência é feita disparando as operações reais (`TotemBooking` + `AppointmentsNotifier` + um `FakeAppointmentService` in-memory) em paralelo com `Future.wait`.

---

## Matriz requisito × achado

| Req. | Cobre | Título |
|---|:--:|---|
| RT-01 | F1 | ID de agendamento único sob 10 criações simultâneas |
| RT-02 | F5 | ID de paciente-convidado único sob cadastros simultâneos |
| RT-03 | F2 | Agendamento do totem persiste entre sessões (some o "agendamento-fantasma") |
| RT-04 | F2 | Os 10 agendamentos simultâneos, todos, sobrevivem ao reload |
| RT-05 | F3 | Capacidade do slot é revalidada — a (N+1)-ésima reserva concorrente é barrada |
| RT-06 | F6 | Senha de fila sem colisão em lote (com dedupe) e contraste com o esquema antigo |
| RT-07 | F8 | Remarcação pelo totem persiste o novo horário |
| RT-08 | F1/F4 | `bookedInSlot` ignora cancelados e respeita data/médico (base da revalidação) |

---

## RT-01 — ID de agendamento único sob concorrência  *(F1)*
- **Objetivo:** garantir que 10 agendamentos criados "ao mesmo tempo" nunca compartilham `id`.
- **Cenário:**
  - **Dado** um `TotemBooking` (com `Random` semeado **e** com `Random` real);
  - **Quando** gero 10.000 ids em laço apertado e 10 ids em paralelo (`Future.wait`);
  - **Então** o conjunto de ids tem exatamente o mesmo tamanho da lista (zero duplicatas), e cada id casa com `^apt-\d+-\d+$`.
- **Aprovação:** `ids.toSet().length == ids.length` em todas as execuções.

## RT-02 — ID de paciente-convidado único  *(F5)*
- **Objetivo:** dois cadastros rápidos simultâneos no totem não podem gerar o mesmo `patientId` (senão fundem pessoas e os limites anti-abuso passam a conflá-las).
- **Cenário:** **quando** gero 10.000 `newGuestPatientId()` + 10 em paralelo; **então** todos distintos e no formato `^totem-\d+-\d+$`.
- **Aprovação:** zero duplicatas.

## RT-03 — Persistência entre sessões  *(F2)*
- **Objetivo:** o agendamento feito no totem tem de chegar ao servidor — não pode existir só na memória da tela.
- **Cenário:**
  - **Dado** um `FakeAppointmentService` in-memory e um `AppointmentsNotifier` ("sessão 1");
  - **Quando** chamo `create(appt)` e aguardo a persistência;
  - **E** descarto a sessão 1 e abro uma **sessão 2** sobre o **mesmo** `FakeAppointmentService`;
  - **Então** a sessão 2 lista o agendamento.
- **Aprovação:** `sessao2.state.any((a) => a.id == appt.id)` é `true`. Teste-espelho negativo: `add()` (método antigo) **não** sobrevive.

## RT-04 — Os 10 agendamentos simultâneos sobrevivem  *(F2)*
- **Objetivo:** o cenário-alvo do pedido — 10 agendamentos simultâneos — persiste **na íntegra**.
- **Cenário:** **quando** 10 pacientes distintos agendam em paralelo (`Future.wait` de 10 `create()`); **então**, numa sessão nova, aparecem os 10, com 10 ids distintos e 10 `patientId` distintos.
- **Aprovação:** `sessao2.state.length >= 10` e `ids/patientIds` sem duplicatas.

## RT-05 — Revalidação de capacidade  *(F3)*
- **Objetivo:** sob concorrência, a capacidade do slot (capacidade + overbook) não é estourada.
- **Cenário:**
  - **Dado** um slot `09:00 × médico d1` com capacidade efetiva **N = 3**;
  - **Quando** simulo 10 tentativas concorrentes, cada uma consultando `TotemBooking.bookedInSlot` e só confirmando se `hasRoom(...)`;
  - **Então** no máximo **3** confirmam; as demais são recusadas.
- **Aprovação:** `confirmadas <= 3` e `recusadas == 10 - confirmadas`. Também: um teste unitário direto de `hasRoom` (booked N-1 → true; N → false; capacidade 0 normalizada para 1).

## RT-06 — Senha de fila sem colisão  *(F6)*
- **Objetivo:** duas pessoas na mesma especialidade não recebem a mesma senha.
- **Cenário:**
  - **Quando** gero 200 senhas para `"Cardiologia"` alimentando o `taken` a cada iteração;
  - **Então** todas são distintas e casam `^C\d{3,}$`.
  - **Contraste:** o esquema antigo (`'$inicial${100+rng.nextInt(900)}'` sem `taken`) produz colisão em 200 emissões — o teste demonstra a diferença.
- **Aprovação:** `senhas.toSet().length == 200`.

## RT-07 — Remarcação persiste  *(F8)*
- **Objetivo:** remarcar pelo totem não pode "voltar" no reload.
- **Cenário:** **dado** um agendamento persistido; **quando** `notifier.move(id, start: novoHorario)`; **então** sessão nova sobre o mesmo Fake mostra `start == novoHorario` e `status == pending`.
- **Aprovação:** horário e status conferem na sessão 2.

## RT-08 — `bookedInSlot` é uma base correta  *(F1/F3)*
- **Objetivo:** a função pura que sustenta a revalidação conta certo.
- **Cenário:** lista com agendamentos em horários variados, um cancelado, um de outro médico, um de outro dia; **então** `bookedInSlot` conta só os ativos do médico/dia/slot, ancora `09:15`→`09:00` numa grade de 30 min, e respeita `ignoreApptId`.
- **Aprovação:** contagens exatas conforme a montagem.

---

## Fora de escopo (registrado, não testado aqui)
- **Atomicidade real** da capacidade exige transação no Firestore — os testes cobrem a *revalidação client-side* (última barreira), não a corrida distribuída entre dispositivos.
- **Troca de médico/especialidade na remarcação** ainda não persiste (limite de `AppointmentService.reschedule`) — RT-07 valida só horário + status.
- Fluxo visual do totem (widget) — bloqueado pelo ambiente; coberto pela lógica extraída em `TotemBooking`.
