# Pontos de Atenção — Radar do Vitta

Documento vivo: o que precisa de decisão, revisão ou vigilância — não é um
changelog. Quando um item for resolvido, mova para "Resolvidos" com a data;
não apague, para o histórico não se perder.

> **Como manter:** ao encontrar um risco novo — segurança, dado que se perde,
> dependência descontinuada, teste flaky — adicione aqui *antes* de corrigir,
> mesmo que a correção seja no mesmo turno. O valor do documento é listar o
> que existe, não só o que já foi resolvido.

---

## 🔴 Crítico — segurança ou perda de dado

### Cloud Functions de I.A. e comunicação não autenticam o chamador
**Status:** aberto — encontrado em 2026-09-01 ao auditar as specs da plataforma
de I.A. É a mesma família dos itens de agenda pública abaixo (endpoint anônimo),
mas aqui o que vaza não é dado: é a **capacidade de agir em nome da clínica**.

As cinco functions HTTPS de IA/comunicação declaram `cors: true` com
`Access-Control-Allow-Origin: "*"` e **nenhuma verifica ID token, App Check ou
aplica rate limit**:

    functions/chatProxy.js:40,45        ALLOWED_ORIGINS = "*"  ·  cors: true
    functions/anthropicProxy.js:30,35
    functions/analyzeDocument.js:55,66
    functions/emailProxy.js:40,45
    functions/whatsappProxy.js:36,39

Verificado por ausência: `grep -nE "Authorization|verifyIdToken|appCheck"` nas
cinco só retorna o `Authorization` que elas **enviam** ao serviço externo —
nenhuma linha lê credencial de quem chamou.

A URL é previsível
(`https://us-central1-agendaclinica-457713.cloudfunctions.net/<nome>`), então
basta saber o nome. O dano por function, do mais barato ao mais grave:

| Function | Um chamador anônimo consegue |
|---|---|
| `chatProxy`, `anthropicProxy` | Usar o Azure/Anthropic da clínica como LLM gratuito — custo direto |
| `analyzeDocument` | Processar documentos na conta Azure |
| `emailProxy` | **Enviar e-mail pelo domínio da clínica** (SendGrid) |
| `whatsappProxy` | **Enviar WhatsApp pela instância da clínica** (Z-API) |

As duas últimas são as sérias: um terceiro fala com pacientes *como se fosse a
clínica*. Phishing com o remetente legítimo, e a reputação do domínio queima
junto.

**Ação (a — recomendada):** exigir Firebase ID token nas cinco. As três de IA
já são chamadas só por usuário logado, então não quebra fluxo nenhum; `emailProxy`
e `whatsappProxy` são chamadas pelas tools MCP, que também rodam autenticadas.
**Ação (b):** restringir `ALLOWED_ORIGINS` ao domínio do app — corta abuso por
navegador, mas não por `curl`; é complemento, não substituto.
**Ação (c):** App Check + rate limit por IP/clínica, junto com o que já está
pendente para `publicAgendaProxy`/`publicAgendaSolicitar` (item abaixo).

---

### `/totem` expõe TODOS os pacientes da clínica para quem acessa sem login
**Status:** aberto — encontrado em 2026-08-29 ao revisar o item abaixo; é a
mesma família de vazamento, mas com escopo maior (a clínica inteira, não um
médico só).

O totem é rota pública (`app_router.dart`, sem redirect de login) e calcula a
grade de horários e as sugestões de especialidade lendo **todos** os
agendamentos da clínica, documento inteiro, direto pelo SDK do cliente:

    lib/core/services/app_providers.dart:726  appointmentsProvider
    → appointmentService.watchForClinic(clinicId)
    lib/features/totem/totem_screen.dart:211  _topSpecialties()
    lib/features/totem/totem_screen.dart:230  _buildSlots()

A UI só mostra contagem de ocupação, mas o Firestore não filtra campos — o
mesmo problema do item abaixo, só que aqui `watchForClinic` traz `nomePaciente`,
`cpf`, `telefonePaciente`, `emailPaciente` e `motivoConsulta` de **todos** os
pacientes da clínica, não só de um médico. Hoje isso está contido pelo mesmo
`firestore.rules`/`EMERGENCIA-firestore.rules` que exige login para tudo — é
por isso que a nota de emergência já lista o totem entre as telas que "param
de funcionar" com a regra fechada. Esta entrada existe para que ninguém reabra
essa leitura sem resolver o vazamento primeiro.

**Ação:** mesma família de solução do item abaixo — uma fonte só de ocupação
(`{ idMedico, dataConsulta, duracao, ocupado }`, sem dado pessoal) atendendo
totem **e** agenda pública, em vez de duas correções separadas.

---

### `/agenda-medico/:id` entrega o documento inteiro do agendamento
**Status:** aberto — correção é de **design**, não de regra do Firestore.
Escopo reduzido em 2026-08-28: `/agenda-publica/:id` (abaixo) já não tem mais
este problema. Ver também o item do totem, acima — mesma causa raiz.

Essa tela (staff da clínica, mas rota pública por QR Code) lê
`tb_agendamentos` filtrado por `idMedico` direto pelo SDK do cliente:

    lib/core/services/app_providers.dart:238  doctorAgendaProvider
    → appointmentService.watchForDoctor(doctorId)
    lib/features/equipe_medica/medico_agenda_screen.dart

Ela mostra nome de paciente **de propósito** (é uma tela de staff), mas o
Firestore não filtra campos — junto do nome vem `cpf`, `telefonePaciente`,
`emailPaciente` e `motivoConsulta` de cada paciente do médico, para qualquer
um que abra o link, logado ou não. Verificado por leitura anônima real contra
o projeto em 2026-08-26 (ver `EMERGENCIA-firestore.rules`, na raiz).

**Ação (a — recomendada):** exigir login nesta rota — é uma tela de staff, não
precisa ser anônima; o QR Code deixa de ser "sem login" mas continua abrindo
direto na agenda certa. **Ação (b):** replicar aqui o padrão que
`/agenda-publica/:id` já usa (Cloud Function com Admin SDK), se o caso de uso
realmente exigir acesso sem login também para esta tela.

---

### `/agenda-publica/:id` — nenhuma regra própria necessária (por design)
**Status:** resolvido pelo desenho, pendente de deploy.

Diferente da tela acima, `/agenda-publica/:id` (perfil do médico + horários +
solicitação de consulta, o link que o profissional compartilha) **não fala
com o Firestore direto**. Leitura e escrita passam por duas Cloud Functions
com Admin SDK (ignora `firestore.rules` de propósito):

    functions/publicAgendaProxy.js       (GET)  → perfil do médico + config de
                                                   horário + horários ocupados
                                                   (sem nome/CPF/telefone/motivo)
    functions/publicAgendaSolicitar      (POST) → grava a consulta como
                                                   `pre-agendado`, com toda
                                                   validação refeita no servidor
                                                   (nome, telefone, vaga,
                                                   duplicidade)

Por isso `firestore.rules` pode manter `tb_agendamentos` **fechado** (leitura
e escrita) para quem não está logado — nenhuma exceção foi aberta nele.

A lógica (`getAgenda`/`solicitar`) foi extraída para `functions/lib/publicAgenda.js`
— fábrica que recebe `db`/`Timestamp` injetados, mesmo padrão de
`lib/dataAccess.js` — e tem 12 testes em `functions/test/publicAgenda.test.js`
contra um Firestore falso (`node --test`, sem subir função HTTP nem projeto
real). Cobre vaga/duplicidade/limite de futuras e, principalmente, que
`getAgenda` nunca devolve nome/CPF/telefone/motivo — a garantia central deste
desenho. `publicAgendaProxy.js` ficou só com a camada HTTP (parse, CORS,
status code).

**Pendências reais, ainda abertas:**
- Sem App Check / rate limiting nas duas Functions — hoje qualquer um pode
  chamá-las direto e martelar `publicAgendaSolicitar` (as travas de vaga/
  duplicidade limitam o dano, mas não o volume de chamadas).
- Deploy pendente: `firebase deploy --only functions:publicAgendaProxy,functions:publicAgendaSolicitar`
  precisa rodar antes da página funcionar de verdade (sem isso, ela cai no
  estado de erro "Não foi possível carregar a agenda").

---

### `firestore.rules` agora versionado — mas não confirmado contra o Console
**Status:** aberto — arquivo criado a partir do que se sabe estar em vigor
(auth obrigatória para tudo, mesma postura de `EMERGENCIA-firestore.rules`),
**não** lido do Console.

`firestore.rules` (raiz do repo) existe agora e `firebase.json` aponta para
ele (`firestore.rules` deploy via `firebase deploy --only firestore:rules`).
Ele fecha `tb_agendamentos` (e tudo mais) para quem não está logado, sem abrir
nenhuma exceção — a agenda pública não precisa disso (ver item acima).

**Ação antes do primeiro deploy:** comparar este arquivo com o que está hoje
no Console (Firestore Database → Regras). Se o Console tiver alguma exceção
que este arquivo não reproduz, a primeira publicação a fecha. Depois do
primeiro deploy bem-sucedido, esta pendência acaba: toda mudança de regra
passa a ser commit revisável.

---

### Totem grava agendamento com a chave de clínica insegura
**Status:** aberto — encontrado em 2026-08-29; é uma instância confirmada do
bug já corrigido em [[clinica-placeholder-no-boot]], num lugar que a correção
de 2026-08-20 não alcançou.

`clinicaResolvidaProvider` existe exatamente para isto (doc do próprio
provider, `app_providers.dart:590`): `selectedClinicIdProvider` vale `'c1'`
(placeholder que não existe no Firestore) até o snapshot real de `tb_clinica`
chegar, e usar esse id como **chave de dado** grava documento órfão. O totem
ainda usa o provider inseguro para gravar:

    lib/features/totem/totem_screen.dart:674
    clinicId: ref.read(selectedClinicIdProvider),

Um totem recém-carregado (reinício de energia, refresh do navegador) que
recebe um agendamento nos primeiros frames grava com `clinicId: 'c1'` — some
no boot seguinte, sem erro visível para o paciente.

**Auditoria dos demais usos — feita em 2026-09-01.** Os outros arquivos que
leem `selectedClinicIdProvider` direto foram verificados um a um:

| Arquivo | Uso | Veredito |
|---|---|---|
| `app_header.dart` · `command_palette.dart` | exibir e trocar a clínica | ✅ correto por design — é o seletor |
| `new_appointment_dialog.dart` · `medico_form_screen.dart` | pré-preenche o formulário | 🟡 exibição; a gravação usa o valor do form |
| `overbooking_providers.dart` | filtro de leitura | 🟡 leitura, `ref.read` |
| `totem_config_provider.dart` · `totem_profiles_provider.dart` | leitura de config | 🟡 documentado inline como deliberado |
| `ia/agent/ia_chats_service.dart` · `agent_plans_service.dart` (×2) · `ia_alerts_provider.dart` | `where('idclinica', ==)` nas listas da `/ia` | 🟡 **só leitura** — as gravações usam `server.ctx.defaultClinicaId` (resolvido) |
| **`totem_screen.dart:674`** | **chave de gravação** | 🔴 **o único bug real** |

Nos quatro da `/ia` há uma assimetria benigna: escreve-se com
`clinicaResolvidaProvider` e lê-se com `selectedClinicIdProvider`. Como
`clinicaResolvidaProvider` é o mesmo id (só devolve `''` enquanto for
placeholder), os dois convergem assim que a clínica resolve; durante o boot a
lista fica vazia e se corrige sozinha no rebuild. Não é perda de dado —
mas vale unificar quando alguém tocar nesses arquivos.

**Ação:** trocar por `clinicaResolvidaProvider` em `totem_screen.dart:674` —
é a única troca que corrige um bug, e não depende das outras.

---

### Fila de recepção não persiste — e o modelo de dados diverge do declarado
**Status:** aberto — decisão de arquitetura pendente.

`RecepcaoNotifier` guarda tudo em memória (senha atual, histórico de chamadas,
contador do dia): reload da aba zera o painel. Mas o problema não é só
persistência — o `ModuleRegistry` já declara as coleções de produção do módulo
(`queue_realoc`, `tb_confirmationHistory`), e o modelo que a tela usa
(triagem Manchester, sinais vitais, microárea/ACS) **não bate** com esse
schema. Ver [[acoes-sem-persistencia]].

**Ação:** decidir se a tela é uma simulação deliberada (e marcar como tal na
UI) ou se deve ser adaptada ao schema real de produção antes de persistir.
Implementar persistência sem essa decisão significa inventar um terceiro
modelo de dados para a mesma fila.

---

### Simulador Monte Carlo: as duas entradas do modelo não existem nos dados
**Status:** aberto — encontrado em 2026-09-02 ao abrir a aba Calibração do
módulo `monte_carlo` contra a base real. Não são defeitos do modelo: são
**dependências de produto anteriores a ele**, exatamente da família que a spec
v2.0 §4 antecipou. Enquanto existirem, qualquer número do simulador é
internamente consistente e descreve uma clínica imaginária.

O que a tela mostrou com 248 consultas e 26 dias de histórico:

| Sintoma na tela | Causa |
|---|---|
| Faixa "Baixo" com **as 248 consultas**; Médio e Alto vazios | `patientRisk` nunca é lido do Firestore |
| Taxa de falta medida em **68,5%**, cancelamento 31,5% — soma exatamente 100% | Nenhum agendamento chega com status `completed` |

**1. `patientRisk` nunca sai do Firestore.**
`FirestoreAppointmentService._fromDoc` monta o `Appointment` sem passar
`patientRisk` (`lib/core/services/appointment_service.dart:244-263`), então todo
agendamento carregado assume o padrão do construtor, `RiskLevel.low`
(`lib/core/models/appointment.dart:23`). Nem existe `RiskLevel.fromString` —
o enum não tem parser (`lib/core/models/enums.dart:93-103`).

Consequência: **a estratificação de risco em que o modelo inteiro se apóia é
ficção.** `ModeloRisco` mapeia três faixas para três probabilidades, mas a
entrada tem uma faixa só. O mesmo vale para o módulo Overbooking, que usa
`patientRisk` para priorizar quem sai do slot em estouro
(`OverbookingEngine._priority`) — hoje todo paciente empata.

**2. Nenhum desfecho `completed` é registrado.**
A soma falta + cancelamento dando 100% só acontece se nenhum agendamento com
desfecho conhecido for `completed`. Ou a clínica não dá baixa de "realizado",
ou o valor gravado não casa com `AppointmentStatus.fromString`.

Consequência: o denominador da taxa de falta contém **apenas fracassos**. Os
68,5% não são a taxa de falta da clínica; são a proporção de faltas entre os
agendamentos que alguém se lembrou de marcar como problema. É viés de seleção,
não medição.

**Por que `φ = 0,90` e `ρ = 0,000` na tela:** o estimador de dispersão roda com
o modelo **já calibrado** (pBaixo = 0,685), então os resíduos fecham e a
sobredispersão some. O motor está certo; ele calibrou fielmente uma base
enviesada. Um `φ` abaixo de 1 com 26 dias é sinal de entrada suspeita, não de
independência — por isso virou aviso explícito na aba.

**Ordem de correção (produto antes de modelo):**
1. Definir onde o risco do paciente nasce (campo no agendamento? cálculo a
   partir do histórico?) e ler no `_fromDoc`.
2. Garantir baixa de "realizado" no fluxo de atendimento, ou mapear o status
   que a clínica de fato usa.
3. Separar "paciente cancelou" de "clínica cancelou" — já registrado abaixo.
4. Só então rodar a calibração para valer.

**Mitigação aplicada em 2026-09-02:** a aba Calibração passou a detectar e
bloquear os dois casos (`MonteCarloCalibracao` → `IntegridadeDados`), em vez de
exibir uma taxa bonita calculada sobre lixo. O botão de aplicar parâmetros fica
desabilitado enquanto houver problema bloqueante.

**Segunda mitigação, mesmo dia:** `_fromDoc` agora **tenta** ler o risco do
agendamento em três formatos (`probabilidade_falta` numérica → `risco_falta`
rótulo → `riscoPercent` escore), e `RiskLevel.fromString` foi criado. Isso
resolve o caso em que o pipeline denormaliza a predição no agendamento.

**Terceira mitigação, mesmo dia:** o join com `tb_faltas_data` (e o fallback em
`dashboard_risco`) foi implementado em
`carregarHistoricoCalibracao` — a nota acima ("ninguém faz o join") ficou
desatualizada assim que isso entrou; deixo o histórico porque documenta a
ordem real da correção. Hoje o caminho é: `tb_faltas_data` > `dashboard_risco`
> campo denormalizado no agendamento > `RiskLevel.low`.

**O que continua em aberto, e não é bug de código:** se a tela ainda mostrar
"todas as consultas em Baixo" depois disso, o mais provável é que
`tb_faltas_data` genuinamente não tenha documento nenhum para esta clínica —
ou seja, o pipeline externo de predição (fora deste repositório) não está
gravando para este tenant. Isso não se resolve lendo o Firestore de outro
jeito; é uma dependência de produto (ligar o pipeline para o tenant, ou aceitar
um proxy de risco calculado localmente a partir de `tb_historico` enquanto o
pipeline não roda).

---

### Projeção 12 meses: nada calibrado, e a spec supõe Azure ML que não existe
**Status:** aberto — 2026-09-02, ao implementar `features/projecao_12m/`.

O motor está correto e testado contra os números que a própria especificação
publica (absorção 69,0/22,1/9,0; superestimativa de 21,9% da conta ingênua).
O que não existe é a **entrada**:

| Falta | Consequência |
|---|---|
| Forecast de série temporal | Volume mensal é parâmetro digitado; o portão de aceite existe mas não tem modelo para avaliar |
| Escore de risco calibrado | A camada 2 da spec (probabilidade individual) não alimenta a projeção |
| Matriz estimada da base | Usa a matriz de referência do documento, não a da clínica |
| Parâmetros de impacto medidos | `reducaoFalta`, `deltaConfirmacao` etc. são hipótese setorial |

`calibradoComDadosReais` é `false` e a tela exibe isso em destaque —
deliberadamente: é a diferença entre apresentar uma projeção e apresentar uma
promessa. **Não remover esse aviso antes do piloto da §16.**

Pendências técnicas menores no mesmo módulo:
- A cadeia não-homogênea (`estimarPorFaixa`) está implementada e testada, mas o
  laço de simulação usa a matriz agregada. A cadeia é **ilustrativa**: as
  contagens projetadas vêm das taxas agregadas, não dela. `estimar`,
  `estimarPorFaixa` e `encolherPara` continuam sem chamador em `lib/` — falta o
  construtor de `EventoTransicao` a partir do histórico real.
- Sem persistência: nenhuma projeção gravada, logo **a cobertura do intervalo
  (§22) não pode ser medida**. `Monitoramento.cobertura` existe e está testado,
  mas não há série de meses fechados para alimentá-lo. É a métrica que valida o
  produto inteiro, e é a única ainda sem dado.
- `deltaConfirmacao` só age na cadeia exibida; não entra nas contagens
  projetadas (que derivam de `reducaoFalta`/`reducaoCancelamento`). Separar é
  deliberado — somar os dois efeitos contaria o mesmo ganho duas vezes —, mas o
  parâmetro parece mais poderoso na tela do que é.
- `fracaoReagendamento` é hipótese sem medição: 40% da massa recuperada. Nenhum
  dado sustenta esse número ainda.

---

### Projeção 12 meses: o intervalo de 12 meses estava metade do que deveria
**Status:** resolvido em 2026-09-03. Registrado aqui porque é o defeito que a
própria especificação v2.0 existe para corrigir — e ele havia reaparecido no
agregado anual.

`_simularCenario` sorteava a camada 2 (Beta, "qual é a taxa verdadeira") **dentro
do laço mensal**, redesenhando doze taxas verdadeiras independentes por
replicação. A incerteza epistêmica então se cancelava por média e encolhia por
√12 ≈ 3,46×. A camada 1 (lognormal do forecast) tinha o mesmo problema: doze
erros mensais independentes fazem o erro do total anual valer `WAPE/√12`.

Medido contra a saída ilustrativa da seção 7 da spec, largura P05–P95:

| Grandeza | Antes | Depois | Alvo (§7) |
|---|---|---|---|
| Agendamentos | 1.631 | 2.604 | 2.630 |
| Faltas | 442 | 905 | 870 |
| Cancelamentos | 231 | 538 | 550 |
| Comparecimentos | 1.175 | 1.997 | 1.990 |

As medianas já batiam antes; só a incerteza estava subestimada — que é
exatamente a forma mais perigosa do erro, porque a projeção parece mais
precisa. Correção: as duas camadas epistêmicas persistem no horizonte, com
`rhoForecast` (padrão 0,15) controlando quanto do erro de forecast é de nível.
O teste `a camada de parâmetro persiste no horizonte` trava a largura relativa
para impedir regressão silenciosa.

No mesmo turno, no mesmo módulo:
- Reposição de vaga incidia sobre a **demanda total** (`demanda * (1 + taxa)`)
  em vez das vagas liberadas por cancelamento — cerca de 8× mais vagas repostas
  do que o parâmetro pedia, inflando a linha de antecipação de demanda. Agora é
  binomial sobre os cancelamentos do mês, com contador explícito.
- `faltasEvitadas` usava diferença de percentis (`base.p05 − novo.p95`), que
  soma as duas incertezas em vez de cancelá-las. Agora os dois cenários rodam na
  mesma replicação com números aleatórios comuns de verdade, e o intervalo é o
  percentil da diferença pareada.
- Ganho negativo era zerado: uma intervenção danosa ficava indistinguível de uma
  inócua. Agora aparece com sinal.
- `mesesComDemandaReprimida` só podia valer 0 ou 12 (contava meses em que >5% das
  replicações estouravam, e todo mês tem a mesma distribuição). Agora é contado
  dentro da replicação, com `probabilidadeEstouro` ao lado.
- `MatrizTransicao.absorcaoDe` destruía massa quando uma linha transitória estava
  vazia, devolvendo distribuição que somava 0 em vez do fallback documentado.
- `Amostradores.binomial` trocava para aproximação normal por `n ≥ 60`. O
  critério certo é a variância: agora é `n·p·(1−p) ≥ 9`, e abaixo disso o sorteio
  é exato por inversão da acumulada.

---

### Projeção 12 meses: equidade, piloto e vazamento implementados
**Status:** resolvido em 2026-09-03. A §8 era descrita como obrigatória para
venda a rede pública e não existia.

Implementados como código executável, não como documentação:
- `equidade.dart` — piso de intervenção validado por **exceção, não `assert`**
  (assert some em release, e é em produção que a regra precisa valer); os seis
  usos proibidos do escore bloqueados em `GuardaEscore`; métricas por subgrupo
  com os critérios da §8.3 (ECE ≤ 0,05 com n ≥ 300, razão de recall ≤ 1,25,
  nenhum subgrupo pior que o baseline).
- `piloto_poder.dart` — reproduz a tabela da §16 até a unidade (5.361 / 2.336 /
  1.287 / 547 / 293 por braço).
- `vazamento_guard.dart` — catálogo da §3.1 com a coluna "disponível em";
  `lembrete_enviado` e `tempo_ate_confirmacao_horas` bloqueados no treino, e
  coluna fora do catálogo tratada como suspeita.
- `risco_calibracao.dart` — isotônica por PAV, ECE, Brier, PR-AUC e o portão
  ECE ≤ 0,03 que libera o escore para o financeiro.
- `monitoramento.dart` — gatilhos numéricos da §13 e Jensen-Shannon.
- `partida_a_frio.dart` — as quatro faixas de maturidade da §17.

**O que ainda não existe:** nada disso tem *dado real* ligado. São motores
corretos esperando entrada — o painel de equidade não tem desfechos por
subgrupo, a calibração não tem escore de modelo, e a guarda de vazamento não
está no CI. Ligar ao CI é o próximo passo barato e de maior retorno.

---

### Simulador: cancelamento do paciente e da clínica no mesmo status
**Status:** aberto — 2026-09-02. `AppointmentStatus.cancelled` é único. Para o
modelo de três estados são eventos opostos: cancelamento do paciente com
antecedência **libera** a vaga e alimenta a lista de espera; cancelamento da
clínica não é desfecho do paciente e não deveria entrar na taxa.

Enquanto o transacional não tiver o campo, `MonteCarloCalibracao` superestima a
taxa de cancelamento e a recomendação de chamadas da fila fica otimista. O
aviso já aparece na aba, mas o dado não existe para corrigir.

---

### Simulador: calibração lê a janela da agenda, não o histórico
**Status:** resolvido (parcialmente) — aberto em 2026-09-02, primeira correção
no mesmo dia, revisto novamente ao investigar por que a tela ainda mostrava
histórico curto depois da correção.

`mcCalibracaoProvider` já não consome `appointmentsProvider` — passou a chamar
`AppointmentService.carregarHistoricoCalibracao`, uma consulta própria ao
Firestore. Mas essa consulta tinha um bug que reproduzia o mesmo sintoma por
outro motivo: `fetchPage` fazia `orderBy(dataConsulta, descending: true)
.limit(800)` numa **única página** — para uma clínica com mais de 800
consultas na janela pedida, isso devolve só as mais recentes. 800 consultas a
~50/dia são 16 dias, não os 120–180 que a fase F2 exige. A tela mostrando "16
dias" com `dias: 180` na chamada era esse corte, não falta de dado no banco.

**Corrigido**: `fetchPage` agora pagina de verdade, com `startAfterDocument`,
até 5 páginas (4.000 documentos) ou até a página vir incompleta — o que
significa que a janela pedida é percorrida por completo até esse teto, em vez
de parar na primeira leitura. A consulta a `tb_faltas_data` (usada para
enriquecer o risco) tinha o mesmo problema, sem `orderBy` nenhum — corrigida
do mesmo jeito. Os índices `(idclinica, dataConsulta)` e
`(idclinica, data_consulta)` já existiam para as duas coleções.

**Ainda em aberto**: o teto de 4.000 documentos por chamada é deliberado (custo
de leitura), mas para uma clínica muito grande ainda pode truncar antes do
fim da janela de 180 dias. Se isso voltar a acontecer, o próximo passo é
paginar em lotes menores ao longo de várias chamadas em vez de uma leitura
única, ou reduzir a janela padrão.

**A terceira consulta, `dashboard_risco` (fallback quando `tb_faltas_data` não
tem match), tinha o mesmo bug e foi corrigida junto** — mas de forma diferente
das outras duas: paginar por `timestampConsulta` exigiria um índice composto
`(clinica, timestampConsulta)` que não existe, e pedir ordenação sem índice
falha silenciosamente (cai no `catch` mudo, e essa camada — que já é o
fallback de terceira linha — voltaria a ficar vazia sem ninguém perceber). A
paginação usa `orderBy(FieldPath.documentId)` em vez disso, que não precisa de
índice novo. Perde-se a garantia de pegar os registros mais recentes primeiro,
mas para uma camada de enriquecimento — não de corte por data — isso não
importa: o objetivo é só não parar de enxergar risco na metade da clínica.

---

### Simulador: `ρ` é fixo, mas `φ` é sazonal
**Status:** aberto — 2026-09-02. `SimulacaoConfig.rho` é um parâmetro parado.
A sobredispersão muda ao longo do ano — chuva, férias escolares, ondas
respiratórias. Um `ρ` estimado em agosto e congelado subestima o risco em
janeiro. Reestimar semanalmente é trabalho de operação e ainda não está
agendado (candidato a `tb_scheduled_tasks`).

---

### Simulador: amostragem trava o frame na web
**Status:** aberto — 2026-09-02. `MonteCarloIsolate` usa `compute`, que na web
roda no mesmo isolate porque não existe `dart:isolate` lá. Com o padrão de
20.000 execuções sobre ~220 consultas são ~4,4 M amostras na thread de UI.

No nativo vai para isolate de verdade e não incomoda. Na web, as saídas são
reduzir `nRuns`, usar `ρ = 0` (forma fechada exata, microssegundos) ou fatiar a
simulação entre frames. Nenhuma implementada.

---

### Simulador: F3 grava, mas ninguém chama
**Status:** aberto — 2026-09-02. `FirestoreMonteCarloRepositorio` está escrito,
testado no mapeamento e ligado no `main`, mas **nenhuma tela chama
`salvarExecucao` ou `registrarDecisao`**. Sem o gatilho não há auditoria: uma
decisão de overbooking tomada hoje não deixa rastro de qual `ρ`, semente e
`labelVersion` a produziram.

Falta decidir *quando* gravar — toda simulação polui a coleção; só na decisão
explicita perde o contexto de quem olhou e não agiu.

---

### Chave de tenant tem cinco grafias — e `tb_agendamentos` tem três
**Status:** aberto — 2026-09-02, ao auditar `.specify/database.md` contra o
código e os índices. Detalhe completo em **database.md → Problemas estruturais,
P1**.

`idclinica` (22), `clinicaId` (14), `clinica` (3), `idClinica` (2), `clinicId`
(1). Em `tb_agendamentos` convivem `idClinica` e `idclinica` no mesmo documento,
e `firestore.indexes.json` tem índices publicados para **três** grafias —
incluindo `id_clinica`, que nem aparece no schema amostrado.

O app compensa abrindo **uma query por grafia** e mesclando
(`appointment_service.dart:208-209`). `watchForDoctor` faz o mesmo com três
formatos de `idMedico`. Custo: 2× e 3× as leituras e listeners por clínica, em
tempo real, por sessão aberta.

**Nada cobre `id_clinica`.** Se existir documento com essa grafia, ele é
invisível para o app — e some da tela sem erro nenhum.

**Verificado na base viva (2026-09-02):** os documentos amostrados de
`tb_agendamentos` têm **`idClinica` e `idclinica` com o mesmo valor** — a
duplicação é redundante, não divergente. Nenhum `id_clinica` apareceu na
amostra. Isso torna o backfill mais barato do que o pior caso previsto, mas a
amostra foi pequena: confirmar com contagem antes de remover o fan-out.

**Ordem de correção:** canonizar `idclinica` → backfill por Cloud Function →
só então remover o fan-out. Inverter os dois últimos passos esconde agendamento
em produção silenciosamente.

**Trava aplicada:** `test/system/schema_tenant_test.dart` congela o conjunto
conhecido — falha se aparecer uma sexta grafia ou se uma coleção hoje limpa
passar a ter duas.

---

### `tb_absenteismo_scores`: quatro índices publicados, coleção VAZIA
**Status:** aberto — 2026-09-02, **confirmado contra a base viva** via MCP do
Firebase: `firestore_list_documents` devolve zero documentos.

Não é a fonte de histórico que a calibração procurava — são quatro índices
custando amplificação de escrita sem nenhum consumidor nem nenhum dado.
**Apagar os índices** ou popular a coleção; hoje ela é só custo.

Contexto original: Os índices são
`clinicaId+outcome+dataConsulta`, `clinicaId+outcome+riskScore`,
`outcome+dataConsulta` e `outcome+riskScore`.

Desfecho + escore de risco + data, por clínica, é **exatamente o histórico que
a calibração do módulo Monte Carlo procura e não acha** — hoje ela lê o
`appointmentsProvider`, limitado à janela operacional da agenda, e por isso
nunca sai de "histórico curto". Nenhum arquivo em `lib/` ou `functions/`
menciona a coleção.

**Verificar se está populada antes de qualquer outro trabalho na fase F2.** Se
estiver, o desenho da calibração muda: deixa de precisar de consulta própria
paginada e passa a ler uma tabela já pronta. Se não estiver, são quatro índices
custando escrita à toa.

Dois dos quatro índices não têm `clinicaId` — permitem consulta cruzando
clínicas. Revisar `firestore.rules` antes de usar.

---

### Telefone gravado como `number` em três coleções
**Status:** aberto — 2026-09-02. `tb_conversas.telefone`, `chat_history.tel` e
`session_chat.tel` são `number`. Perde zero à esquerda, estoura precisão em
número internacional longo e impede prefixo `+`.

As coleções que acertam (`tb_agendamentos.telefonePaciente`,
`queue_realoc.telefonePaciente`) usam `string`. As três erradas são justamente
as do fluxo de WhatsApp — onde o número é a chave de correlação.

---

### CPF como id de documento em `patient_reputation`
**Status:** aberto — 2026-09-02. O id do documento é o CPF (`00357184256`) e o
CPF também está em campo.

Id de documento aparece em log de acesso, chave de índice, URL de console e
mensagem de erro — lugares dos quais um `delete` do documento não remove o
dado. Pedido de exclusão do titular (LGPD) não fica atendido de verdade.

**Correção:** id sintético (usar `patientId`), CPF só em campo.

---

### `tb_configuracao_chat` duplica o cadastro inteiro dos médicos
**Status:** aberto — 2026-09-02. O campo `medicos` é um `array<map>` com dados
pessoais, especialidades, foto, ticket e a agenda dos sete dias de **cada**
médico — uma cópia de `tb_medicos` dentro de um documento de configuração.

O documento cresce com o número de médicos e **o teto do Firestore é 1 MB**.
A cópia também envelhece: mudar horário em `tb_medicos` não atualiza aqui.

Pior: `tb_configuracao_chat.clinica` traz `cidade`, `estado`, `endereco`, `site`,
`modalidade` e `especialidades`, que **não existem em `tb_clinica`**. Hoje a
fonte de verdade do endereço da clínica é um documento de configuração de chat.

---

### Agente de IA: 79 ferramentas em toda requisição, em toda rodada
**Status:** aberto — 2026-09-02, medido.

`mcpServerProvider` expõe **79 ferramentas**; o JSON de specs tem **44 KB
(~11.000 tokens)** e vai inteiro em **cada** requisição. Com `maxRounds: 6`,
uma pergunta pode reenviar ~66 mil tokens só de catálogo, antes de qualquer
conteúdo de conversa.

O modelo também escolhe pior com 79 opções do que com 15 relevantes.

**Saída:** filtrar o catálogo por intenção antes de enviar (grupo de tools por
assunto, ou seleção por similaridade com a pergunta). Não implementado — exige
decidir a estratégia de seleção, e uma heurística ruim quebra o agente em
silêncio (ele deixa de ter a ferramenta que precisava).

**Já aplicado no mesmo dia** (ganhos menores, sem risco):
- `ok()` passou a serializar **JSON compacto**: −26% de bytes, ~927 tokens
  poupados por listagem de 50 itens — e o resultado é reenviado a cada rodada
  seguinte, então o ganho se multiplica.
- `ctx.limit()` ganhou teto de 200. Era ilimitado, e o valor vem do LLM: um
  `limite: 50000` devolvia 50 mil registros para o contexto. Negativo também
  passava e estourava em `Iterable.take`.
- `prazoTotal` de 3 min por rodada do agente. Sem ele,
  `maxRounds × maxRetries × 90 s` chegava a ~27 min com a interface travada.
- Resultado de ferramenta truncado em 8.000 caracteres **com marca explícita**,
  para o modelo saber que há mais dado e refazer com filtro.
- `ToolExecutor` passou a devolver `(text, isError)`. O laço detectava falha por
  `result.startsWith('Erro:')` — sniffing que errava nos dois sentidos.

---

## 🟡 Importante — inconsistência, dívida técnica ou monitoramento ausente

### Specs da plataforma de I.A. descreviam um app Next.js que não existe aqui
**Status:** resolvido em 2026-09-01 — fica registrado porque a **causa raiz
continua**: as specs vieram do projeto irmão `app_company` e ninguém as
reescreveu ao portar para Flutter.

`MCP.md`, `TAREFAS_AGENDADAS.md`, `AgentAI.md` e `AI_chaves.md` documentavam
rotas `/api/*`, `src/lib/*.js`, transports do SDK do MCP, Vercel Cron e sessão
`__session`. O código real é Dart (`lib/core/modules/mcp/`,
`lib/features/ia/`) + Cloud Functions do Firebase.

O caso mais grave foi `TAREFAS_AGENDADAS.md` §3, que documentava
`DEFAULT_CLINICA = JuhdNt7NG3GYOFKOKOXP` como constante viva — **exatamente o
fallback de clínica que `MCP.md` registra como removido em 2026-08-20 por ser
furo de isolamento multi-tenant**, com a instrução "não reintroduza". Duas
specs da mesma pasta se contradiziam, e a errada nomeava o valor a
reintroduzir. É o cenário que o `README.md` descreve: alguém "conserta" o
código para bater com a spec.

**Ação (feita):** as quatro reescritas contra o código, cada uma com uma seção
§0 de portabilidade mapeando "o que a spec antiga dizia → o que existe".
**Ação (aberta):** ao trazer qualquer doc de `app_company`, reescrever antes de
commitar — ou marcar explicitamente como spec de outro projeto.

---

### RBAC por papel está documentado, mas não existe no app
**Status:** aberto — encontrado em 2026-09-01.

`MCP.md` §9/§10 e `TAREFAS_AGENDADAS.md` §10 descreviam (até serem corrigidos)
uma matriz `admin`/`rsa`/`med` com `canUseSchedules`, `requireScheduleAccess` e
tools escondidas por papel. Nada disso foi portado: `AppUser.roles`
(`lib/core/models/app_user.dart:64,76`) é lido **só** para montar `roleLabel`,
um rótulo de exibição.

Consequência: qualquer usuário logado tem as 75 ferramentas MCP, incluindo
`agendar_tarefa`, `email_enviar_em_lote` e `whatsapp_enviar_em_lote`, e pode
aprovar rotinas sugeridas pela IA em `/tarefas-agendadas`.

Isso **não** quebra a garantia central (a IA continua sem executar sozinha —
as três travas são de status, não de papel). O que falta é distinguir *qual*
humano aprova. Numa clínica pequena talvez não importe; numa rede com perfil
`med`, importa.

**Ação:** decidir se o RBAC entra. Se entrar, o ponto natural é
`createMcpServer` (filtrar `groups` por papel) + guarda de rota no
`app_router.dart` — não espalhar checagem por tela. Se não entrar, manter as
specs dizendo que não existe, como estão agora.

---

### `McpCache` e `anthropicProxy`: código publicado sem chamador
**Status:** aberto — encontrado em 2026-09-01. Baixo risco, custo real.

Dois casos de código vivo que ninguém invoca:

1. **`lib/core/modules/mcp/mcp_cache.dart`** — 68 linhas de cache com TTL.
   `grep -rn "McpCache" lib/ test/` só retorna o próprio arquivo. `MCP.md`
   descrevia como camada ativa com TTL de 2 min (corrigido). Como não há
   cache, os SOPs de `CUSTO.md` §6.2 (context cache por execução) não valem
   para o lado Dart — cada tool vai direto ao Firestore.
2. **`functions/anthropicProxy.js`** — publicada, consome o segredo
   `ANTHROPIC_API_KEY`, e `grep -ri anthropic lib/` não retorna nada. É
   superfície de ataque (ver item 🔴 acima) e um segredo mantido à toa.

**Ação:** para (1), ligar o cache nas tools de leitura ou apagar o arquivo —
mantê-lo documentado como ativo é o pior dos três estados. O cache do módulo de
Evidências (`tb_pubmed_cache`, em `functions/lib/pubmed.js`) serve de
referência: chave por hash de `(ação, params)`, TTL por tipo de operação e
falha silenciosa que nunca derruba a consulta. Para (2), remover a
function e o segredo, ou registrar para que serve.

---

### Runner Dart executa tarefas sem orçamento de leituras
**Status:** aberto — encontrado em 2026-09-01.

`functions/scheduledTasksCron.js` protege cada execução com
`makeReadMeter(READ_BUDGET = 1500)` (`CUSTO.md` §6.8) — estoura, aborta. O
`vigiaCron` reutiliza o mesmo medidor.

O lado Dart não tem equivalente: `ScheduledTasksRunner._execute` e
`VigiaService._executar` chamam `servidor.callTool` direto, sem contagem. Os
únicos limites são o timeout (4 min no runner, 5 min no Vigia) e as 6 rodadas
do loop do agente.

Na prática: uma tarefa que o cron abortaria por custo roda até o fim quando
disparada pelo catch-up da tela ou pelo "executar agora". Com
`consultar_colecao` sem filtro no prompt (a tool mais cara, `CUSTO.md` §3.1),
isso é uma varredura sem teto.

**Ação:** portar `makeReadMeter` para Dart e envolver `McpContext` — é o mesmo
lugar onde o filtro de tenant já roda, então o medidor pega todas as leituras
sem tocar em cada tool.

---

### Faturamento desabilitado no GCP — derruba TODA a IA e todo deploy
**Status:** aberto — **o bloqueio mais grave da lista**. Descoberto em
2026-09-02 ao tentar publicar a `pubmedProxy`; o alcance real apareceu depois.

**Não é só deploy: a IA está fora do ar em produção.** O log da `chatProxy`,
que já está publicada, mostra o mesmo motivo a cada requisição:

    E chatproxy: The request failed because billing is disabled for this project.

Ela precisa ler `AZURE_AI_KEY` do Secret Manager, e o Secret Manager exige
faturamento. Resultado: **toda função que dependa de segredo responde 500/503**.
Isso atinge o chat do `/ia`, o Vigia, o assistente de ajuda, os relatórios por
IA, o modo Perguntar e o Chat das Evidências — tudo o que passa pelo modelo.

Sintoma na tela até 2026-09-02: *"Credencial da IA recusada (HTTP 401)"*, que
mandava para o lugar errado (auditar uma chave que nem chega a ser usada). A
mensagem foi corrigida para distinguir três casos — build sem configuração,
credencial de fato recusada, e Cloud Function caindo com 5xx.

    Error: Request to secretmanager.googleapis.com/.../AZURE_DOCINTEL_KEY
    had HTTP Error: 403, This API method requires billing to be enabled.

**Não é problema da `pubmedProxy`.** O deploy analisa o codebase inteiro e
falha ao ler os *secrets* de qualquer function. Enquanto o faturamento estiver
desligado, **nenhuma** function pode ser publicada ou atualizada — nem correção
de bug nas que já existem.

As já publicadas continuam rodando (verificado: `chatProxy` responde). O que
está congelado é a capacidade de publicar.

**Enquanto o faturamento não volta**, dá para desenvolver com a IA ligada
apontando direto ao Azure: copie `.dart-defines.example.json` para
`.dart-defines.json` (ignorado pelo git), preencha `AZURE_AI_KEY` e use o
perfil `vitta-web-ia-direta` do `.claude/launch.json`.

> ⚠️ Esse perfil embarca a chave no bundle JavaScript. Serve para
> desenvolvimento, **nunca** para gerar build de produção.

**Ação (só o dono do projeto pode):** habilitar o faturamento em
https://console.developers.google.com/billing/enable?project=agendaclinica-457713
e repetir:

    firebase deploy --only functions:ia:pubmedProxy

A configuração do NCBI já está pronta em `functions/.env` (fora do git):
`NCBI_TOOL=vitta_app`, `NCBI_EMAIL=contato@agendaclinicas.com.br`. O deploy
confirmou que ela é lida (`Loaded environment variables from .env`).

---

### `pubmedProxy` não publicado — módulo degradado, não parado
**Status:** aberto, mas rebaixado em 2026-09-01 (deixou de bloquear a tela).

A Cloud Function `pubmedProxy` existe, tem 37 testes
(`functions/test/pubmed.test.js`) e **ainda não foi publicada** — confirmado em
2026-09-01: o endpoint devolve 404.

**A tela funciona mesmo assim.** Desde 2026-09-01 o app cai para um conector
direto ao NCBI quando o proxy não responde, e mostra um aviso dizendo que está
consultando o PubMed diretamente. O deploy deixou de ser bloqueador e passou a
ser melhoria — ver `.specify/EVIDENCIAS.md` §3.0 para o que muda entre os dois
caminhos.

**O que ainda se ganha publicando:** limite de taxa coordenado (o do NCBI é por
IP e o IP é compartilhado), cache entre clínicas, API key (10 req/s em vez de
~3) e a guarda de PHI num lugar que o usuário não alcança.

> ⚠️ **Publicar SEM configurar não adianta — e antes piorava.** A função exige
> `NCBI_TOOL` e `NCBI_EMAIL`; sem elas responde 503. Até 2026-09-01 esse 503
> **não** disparava o plano B, então o deploy sem config deixava a tela pior do
> que antes dele. Corrigido: `NOT_CONFIGURED` agora degrada para o caminho
> direto como qualquer outra indisponibilidade. Ainda assim, publicar sem
> configurar não traz benefício nenhum.

**Antes do deploy**, defina:

| Variável | Valor | Obrigatória |
|---|---|---|
| `NCBI_TOOL` | `vitta_app` | sim |
| `NCBI_EMAIL` | e-mail do responsável técnico | sim |
| `NCBI_API_KEY` | segredo, gratuito | não (eleva ~3 → 10 req/s) |

`NCBI_EMAIL` precisa ser um endereço real e monitorado: é por ele que o NCBI
avisa antes de bloquear o IP do projeto.

    firebase deploy --only functions:pubmedProxy

**Não remova o `verifyIdToken`** para facilitar teste. O limite do NCBI é por
IP e o IP é compartilhado pelo projeto: um proxy aberto faria o NCBI barrar o
tráfego de **todas** as clínicas ao mesmo tempo. É a única function do repo que
autentica — ver `.specify/EVIDENCIAS.md` §3.1.

---

### `vigiaCron` escrito e testado, não publicado
**Status:** aberto — decisão de deploy pendente (`.specify/CLOUD_FUNCTION.md` §5).

O ciclo diário do Vigia só roda hoje quando alguém abre o app (cliente Dart).
A function agendada (06:00 BRT) existe, tem 18 testes e reusa o loop de
ferramentas do `scheduledTasksCron` — falta só `firebase deploy --only
functions:vigiaCron`. Sem isso, um dia sem ninguém abrir o app é um dia sem
análise nem relatório.

**Ação:** publicar quando a operação já estiver confortável com o volume de
sugestões que o Vigia gera hoje pelo cliente.

---

### Relatório de erro existe, mas ninguém olha e some nas telas públicas
**Status:** aberto — texto anterior deste item ("nenhum relatório de erro em
produção") ficou desatualizado; achado ao revisar em 2026-08-29.

`ErrorReporter` (`lib/core/services/error_reporter.dart`) já existe, está
instalado no `main.dart` e grava erros não tratados em `tb_error_logs` — não é
Crashlytics (deliberado: o app roda em 6 plataformas, Crashlytics só cobre
Android/iOS), é Firestore direto, com dedupe e teto por sessão. Duas lacunas
reais:

1. **Ninguém lê `tb_error_logs`.** Nenhuma tela do app consulta essa coleção —
   os erros são gravados num buraco negro. `grep -rn tb_error_logs lib/` só
   retorna quem escreve.
2. **Vai parar de gravar exatamente nas telas públicas** (totem, agenda
   pública, agenda do médico, monitor) assim que `firestore.rules` (auth
   obrigatória) for publicado — `_gravar()` engole a exceção de permissão
   silenciosamente, por design ("perder o log é aceitável, travar não é").
   Ou seja: as telas sem rede de segurança de login também ficam sem rede de
   segurança de observabilidade.

**Ação:** uma tela mínima em `/configuracoes` ou `/arquitetura` listando os
últimos N erros de `tb_error_logs` resolve (1). Para (2), ou aceitar a lacuna
(erro anônimo é o de menor prioridade) ou dar a `tb_error_logs` uma regra
própria de `create` sem login, restrita ao formato do payload — mesmo padrão
já usado para `publicAgendaSolicitar`, mas exige medir volume antes: log de
erro sem limite de taxa em rota pública é superfície de custo, não só de dado.

---

### `firestore.indexes.json` pode voltar a dessincronizar
**Status:** monitorar — corrigido em 2026-08-25 (ver [[firestore-indexes-sincronizados]]).

O arquivo tinha 113 de 145 índices reais até esta correção. A causa raiz — outra
parte do sistema cria índices sem passar por este repositório — continua
existindo, então o desvio pode voltar.

**Ação:** antes de qualquer `firebase deploy --only firestore:indexes --force`,
rodar `firebase firestore:indexes` e comparar com o arquivo local.

---

### `flutter_markdown` descontinuado
**Status:** aberto — sem prazo definido.

O pacote que renderiza o chat de IA e o editor VFM do Cérebro (6 arquivos) foi
descontinuado; sucessor é `flutter_markdown_plus`. Ainda funciona, mas não
recebe correção de segurança nem de bug.

**Ação:** migração precisa validar as extensões de sintaxe do VFM (wikilinks,
`[[@tipo:id]]`) uma a uma — não é troca de import. Não fazer sem janela
dedicada a testar visualmente o editor do Cérebro depois.

---

### 22 dependências presas em versão major antiga
**Status:** monitorar.

`flutter pub outdated` mostra 22 pacotes cujo `pubspec.yaml` trava numa major
mais velha que a resolvível, além de 10 presas por `pubspec.lock`. Isso não é
urgente isoladamente, mas quanto mais tempo passa, mais major versions se
acumulam entre a instalada e a atual — e maior o risco de um upgrade futuro vir
em lote, com várias breaking changes simultâneas em vez de uma de cada vez.

**Ação:** revisar em uma janela tranquila, pacote a pacote — não em lote.

---

## 🟢 Cosmético — sem risco, mas vale registrar

### Link externo não abre fora da web
`openExternalUrl` (`lib/core/utils/platform_share.dart`) só tem implementação
em web; o stub das demais plataformas é no-op, porque o projeto não usa
`url_launcher` (a mesma escolha está registrada em `clinic_map_stub.dart`).

No módulo de Evidências isso apareceria como "toquei em *Abrir no PubMed* e
nada aconteceu", então ali o link é copiado para a área de transferência com
aviso, fora da web. Funciona, mas é degradado.

**Ação:** adicionar `url_launcher` resolveria de vez, para este módulo e para o
mapa da clínica. Decisão de dependência — vale avaliar junto.

### `ModuleRegistry` declara coleções que o módulo de I.A. não usa
**Corrigido em 2026-09-01** para o módulo de IA: `ownedCollections` agora
declara `tb_relatorio_ia`, `tb_ia_chats` e `tb_agent_plans` (antes eram `chats`
e `chat_history`, que não existem no código).

A causa raiz continua: nada verifica o registry contra o código. Os demais
módulos não foram auditados um a um. Sem efeito em runtime — o registry alimenta
a tela `/arquitetura` e a paleta de comandos — mas é mapa errado para quem for
auditar custo ou regra por coleção.

### Overflow de layout no boot do shell — cosmético, mas mascarado
**Status:** aberto.

O `integridade_sistema_test.dart` reporta, a cada execução:

    boot → A RenderFlex overflowed by 20 pixels on the right.

São 20 overflows conhecidos espalhados pelas rotas (`/health-score` sozinho tem
9). O teste os classifica como cosméticos e não reprova — o que é razoável para
não travar a suíte, mas tem um custo: **ninguém olha mais para eles**, e um
overflow novo entra na lista sem chamar atenção.

**Como isso mordeu em 2026-09-01.** O handler de erro do teste era restaurado
com `addTearDown`, que roda **antes** de o `testWidgets` descartar a árvore. O
overflow reaparecia na disposição, caía no handler padrão e reprovava o teste —
com um `RenderFlex` já `DISPOSED`, impossível de rastrear até um widget.
Corrigido movendo a restauração para o `tearDown` do grupo.

**Ação:** os 20 overflows continuam lá. Vale caçá-los por rota; o
`/evidencias` já foi (era o painel de filtros e a linha de controles, corrigidos
com `Flexible` e `Wrap`).

---

### Lint `info` pendente em `overbooking_widgets.dart:645`
`unnecessary_underscores` — inofensivo, nunca chegou a ser limpo por não
bloquear nada. Corrige-se em segundos quando alguém tocar naquele arquivo por
outro motivo.

### Teste pulado por limitação de harness, não bug
`test/system/navigation_flow_test.dart:81` — `skip: true`, com o motivo
documentado inline: o tap na `NavigationBar` não dispara `context.go` de forma
confiável no harness de widget test com `go_router`. O roteamento em si é
coberto por `plan_redirect_test` e outro teste de navegação. Não requer ação.

---

## Backlog de melhorias — não são riscos, são oportunidades

Ordenado por esforço estimado. Nenhum destes tem problema hoje; são o que
levaria o produto adiante. Peça para detalhar antes de qualquer um virar
trabalho — os tamanhos abaixo são estimativa de conversa, não investigação.

| Recurso | Esforço | Por quê |
|---|---|---|
| Autenticar as 5 functions de IA/comunicação | P | Fecha o item 🔴 mais barato de resolver da lista |
| Marcar a tela de Recepção como demo (ou iniciar a adaptação ao schema real) | P | Desbloqueia decidir o item 🔴 acima |
| Decidir sobre `McpCache` e `anthropicProxy` (usar ou remover) | P | Código publicado sem chamador — ver item 🟡 |
| Tela de visualização de `tb_error_logs` | P | O reporter já grava; falta quem leia — ver item 🟡 |
| Gravar o `outcome` do agendamento após a data | P–M | Destrava **todas** as métricas de eficácia da IA (`AgentAI.md` §7) |
| Portar `makeReadMeter` para o lado Dart | P–M | Paridade de teto de custo com o cron — ver item 🟡 |
| Exportar o vault do Cérebro (Markdown/JSON) | P–M | Backup e confiança do usuário no próprio dado |
| Painel de métricas do Vigia (aprovado × recusado) | M | Fecha o ciclo de confiança na IA |
| RBAC por papel (`admin`/`rsa`/`med`) | M | Hoje qualquer logado aprova rotina da IA — ver item 🟡 |
| Trilha consultável de ações do agente | M | `history[]` guarda só 20 execuções por tarefa |
| Dashboard de custo de IA por dia/clínica | M | Os SOPs de custo já existem (`CUSTO.md`); falta a tela |
| Anexos em notas do Cérebro | M | Fecha o caso de uso clínico (exame ligado à análise) |
| Vigia configurável por setor, não só por clínica | M | Reduz ruído em clínicas grandes |
| Confirmação de WhatsApp bidirecional (paciente responde) | M–G | Fecha o loop de confirmação sem humano no meio |
| Indicador de risco de falta na grade de agendamentos | M | O score já existe no modelo; falta expor na UI principal |
| Busca salva + alerta de nova literatura (PubMed) | M | `tb_scheduled_tasks` já suporta; fecha o caso "acompanhar tema" |
| Busca semântica no Cérebro (embeddings) | G | Maior salto de qualidade de busca; maior investimento |
| Testes contra o Firestore Emulator Suite | G | Pega erro de regra/índice antes da produção; setup não-trivial |

**P** = horas · **M** = 1–3 dias · **G** = mais de uma semana ou decisão de
arquitetura antes de começar.

---

## Resolvidos

| Item | Resolvido em | Nota |
|---|---|---|
| Clínica placeholder gravando/lendo dados na clínica errada no boot | 2026-08-20 | [[clinica-placeholder-no-boot]] |
| Cérebro auto-populava 1.200 notas sintéticas sem pedir | 2026-08-20 | [[cerebro-nunca-auto-popula-demo]] |
| MCP sem clínica resolvida operava em clínica arbitrária | 2026-08-20 | [[mcp-sem-clinica-fail-closed]] |
| Perfil, agentes, notificações, relatórios sem persistência | 2026-08-20/21 | [[acoes-sem-persistencia]] |
| Índice O(N²) na indexação do Cérebro (75 s → <1 s em 3.000 notas) | 2026-08-21 | [[cerebro-performance-indice]] |
| Boot da tela do Cérebro travava a UI durante a indexação | 2026-08-21 | [[cerebro-boot-fatiado-e-ticker]] |
| Rotinas de IA sem garantia de aprovação humana | 2026-08-21 | [[vigia-nunca-executa-sozinho]] |
| Notas clínicas de pacientes sem persistência | 2026-08-25 | [[acoes-sem-persistencia]] |
| Cadastro de agente sem login real (Auth + `users`) | 2026-08-25 | [[acoes-sem-persistencia]] |
| `firestore.indexes.json` desincronizado (113 de 145) | 2026-08-25 | [[firestore-indexes-sincronizados]] |
| Sem CI/CD — suíte só rodava se alguém lembrasse | 2026-09-01 | `.github/workflows/ci.yml`: `flutter analyze` + `flutter test --concurrency=1` + testes das functions, em PR e push para `main` |
