# Simulador — Planejador automático por I.A.

Complemento ao módulo Monte Carlo (`lib/features/monte_carlo/`). Cobre só a
camada de I.A. acrescentada em 2026-09-02; o motor de simulação, a calibração
e os parâmetros estão documentados no próprio código.

> **Tela**: `/monte-carlo`, aba **Planejador**
> **Código**: `lib/features/monte_carlo/ia/`

---

## 1. O processo que isto automatiza

Sem o Planejador, o gestor faz isto para montar a semana:

1. abre o Simulador
2. escolhe uma data
3. lê a aba Decisão
4. anota quantos encaixes cabem
5. avança um dia — e repete

Cinco a sete vezes, toda semana. O Planejador faz a varredura de uma vez e
entrega o que sobrava de trabalho humano: **onde olhar primeiro e por quê**.

---

## 2. A divisão de trabalho — e por que ela é rígida

| Quem | Faz o quê |
|---|---|
| `ExecutorPlano` | produz **todos** os números (encaixes, risco, receita, ociosidade) |
| `AgenteSimulacao` | **só interpreta** — prioriza, explica, alerta |
| `ValidadorNumeros` | confere que a IA não inventou nenhuma cifra |

**Isto não é preciosismo de arquitetura.** A saída deste módulo vira decisão de
agenda. Uma clínica que encaixa 6 pacientes porque a IA escreveu "6" — quando a
simulação disse 2 — coloca quatro pessoas a mais numa sala de espera real.

O modelo nunca tem acesso à aritmética: recebe o resultado pronto e escreve
sobre ele.

É o mesmo desenho do módulo de Evidências: o código produz o fato, o modelo
explica, e uma checagem determinística recusa o que não bate. Lá a âncora é o
PMID; aqui é a cifra.

---

## 3. As três travas

**1. Não calcula.** Os números vêm de `ExecutorPlano`, que é determinístico —
mesma semente, mesmo plano. É o que permite o gestor conferir depois o que foi
decidido. Coberto pelo teste *"é reprodutível: mesma semente, mesmo plano"*.

**2. Não aplica.** A saída é uma `SugestaoPlano`. Nada é gravado na agenda;
encaixar é ação do gestor, num segundo passo explícito. É a mesma regra do
Vigia ([`VIGIA.md`](VIGIA.md)): rotina de I.A. nasce como proposta. A tela diz
isso em texto, e há teste garantindo que a frase está lá.

**3. Não passa sem conferência.** `ValidadorNumeros` compara cada cifra do
texto com o conjunto que a simulação produziu, e marca no texto o que não bate
— marca, não apaga, pelo mesmo motivo das citações inventadas em Evidências:
apagar deixaria a frase de pé afirmando o mesmo, sem nada que denuncie.

### O que o validador NÃO checa, de propósito

Percentual, hora, ordinal e data passam livres. Exigir que "100%", "9h" ou
"1º dia" estivessem no conjunto encheria a tela de alarme falso — e alarme
falso treina o gestor a ignorar o aviso, que é o único jeito de a trava deixar
de funcionar.

Há um teste que trava exatamente isso: *"NÃO acusa percentual, hora, ordinal
nem data"*.

### Um teste que fecha o círculo

*"os números permitidos cobrem o que o prompt mostra"* valida o **próprio
prompt** contra o validador. Se um número aparece no prompt e não no conjunto
permitido, a IA seria acusada de inventar o que nós mesmos demos a ela.

---

## 4. Decisões de interface

**Os números aparecem antes da análise.** A varredura e a interpretação são
fases separadas na tela: os cartões de dia surgem assim que a simulação
termina, e o texto da IA chega depois. Esperar a IA para mostrar a simulação
faria o gestor olhar um spinner por causa de um complemento.

**Se a IA cair, some só o cartão dela.** O plano continua na tela e continua
utilizável — porque o produto desta aba são os números. Coberto por *"IA fora
do ar NÃO derruba o plano"*.

**A análise fica abaixo dos números, rotulada como leitura da I.A.** A ordem
importa: quem chega vê primeiro o que foi calculado. Inverter treinaria o
gestor a ler a opinião como se fosse o dado.

**O progresso mostra o dia, não uma barra indeterminada.** A varredura leva
vários segundos; "3 de 7" diz quanto falta, uma barra girando faz a tela
parecer travada.

**A cor do cartão é "quanto olhar", não "risco".** Um dia tranquilo com 3
encaixes livres é verde; um dia cheio que não aceita encaixe nenhum é vermelho,
ainda que a simulação esteja perfeita. São perguntas diferentes.

**Dia sem agenda e dia que falhou aparecem na faixa.** Omitir daria a impressão
de que o dia foi olhado e estava tranquilo.

---

## 5. Estrutura

```
lib/features/monte_carlo/
├── ia/
│   ├── plano_semanal.dart      ← varredura determinística (sem I.A.)
│   ├── agente_simulacao.dart   ← a camada de I.A., só interpreta
│   ├── validador_numeros.dart  ← a trava anti-cifra-inventada
│   └── mc_ia_providers.dart    ← estado do planejador
└── widgets/
    └── mc_planejador_tab.dart  ← a interface gráfica da I.A.

test/features/
├── monte_carlo_ia_test.dart          ← 18 testes (validador, executor, plano)
└── monte_carlo_planejador_test.dart  ← 12 testes de widget
```

---

## 6. Limite conhecido

A varredura roda **na thread da UI**, ao contrário da aba Decisão, que usa
isolate (`monte_carlo_isolate.dart`). Com 7 dias e as configurações padrão o
custo é aceitável e o progresso é visível a cada dia; com 14 dias e `nRuns`
alto, a interface engasga.

Passar a varredura para o isolate é o próximo passo natural — exige mover o
laço inteiro para lá, porque o ganho some se cada dia pagar a serialização
separadamente.
