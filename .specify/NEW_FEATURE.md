### Visualização e Feedback Visual no Totem
O sistema traduz os números acima em cores para orientar o paciente de forma intuitiva:

| Intensidade | Cor do Botão | Significado para o Paciente |
| :--- | :--- | :--- |
| **0% a 49%** | Verde (Zinc-50/Primary) | Horário livre e tranquilo. |
| **50% a 79%** | Amarelo (Amber-50/400) | Horário com procura moderada. |
| **80% a 99%** | Vermelho (Red-50/500) | **Últimas vagas!** Horário muito concorrido. |
| **100%** | Cinza/Desabilitado | Horário lotado (Capacidade total atingida). |

---

## 6. Segurança e Validação de Fluxo

### Prevenção de Agendamentos Duplos
O sistema impede que o mesmo CPF realize dois agendamentos ativos na mesma data. Caso o paciente tente, o Totem sugere a funcionalidade de **Remarcar**, permitindo que ele mova o horário existente em vez de criar um novo conflito.

### Gestão de Sessão (Timer de 120s)
Implementado via `TotemSessionProvider`, um temporizador reinicia a cada interação. Se o paciente abandonar o totem no meio do preenchimento do CPF, os dados são limpos após 120 segundos, garantindo a privacidade das informações.

---

## 7. Códigos de Referência Core

### Geração de Senha (Pass)
Utiliza a primeira letra da especialidade seguida de 3 dígitos aleatórios.
```typescript
const pass = `${specialty.charAt(0).toUpperCase()}${Math.floor(100 + Math.random() * 900)}`;
```

### Normalização de Status para Auditoria
```typescript
// Unifica termos variáveis (noshow, falta, ausente) em um estado consistente
const normalize = (s) => ['noshow', 'falta', 'ausencia'].some(k => s.includes(k)) ? 'nao_compareceu' : s;


# Documentação Técnica: Ecossistema de Atendimento Vitta Care

Este documento detalha a lógica de negócio, algoritmos e integrações do sistema de gestão de atendimento, monitoria e autoatendimento (Totem).

---

## 🚀 1. Lógica de Ocupação e Overbooking Inteligente

O sistema utiliza um algoritmo de **Capacidade Dinâmica** para determinar se um horário está disponível, permitindo que a clínica maximize a ocupação sem sobrecarregar os médicos.

### 🧩 Níveis de Cálculo de Limite
A capacidade total de um slot (ex: 08:00h) é calculada cruzando quatro fontes de dados no objeto do médico:

1.  **Limite Base (`limiteSlot`)**: O número padrão de pacientes por horário (ex: 1).
2.  **Overbook Global (`security.maxOverbook`)**: O limite extra permitido em qualquer cenário.
3.  **Overbook por Dia (`overbookingConfig[dia]`)**: Permite que segundas-feiras tenham mais overbooking que sextas, por exemplo.
4.  **Overbook por Período (`overbookingPeriodo[turno]`)**: Define limites diferentes para Manhã, Tarde e Noite.

### 🔢 O Algoritmo de Disponibilidade
O código realiza a seguinte operação para cada slot gerado:

```typescript
// Extração das configurações do médico
const baseLimit = doctor.limiteSlot || 1;
const security = doctor.limitesSeguranca;
const dayConfig = doctor.overbookingConfig[diaDaSemana];
const periodConfig = time < "12:00" ? morning : (time < "18:00" ? afternoon : evening);

// Cálculo do Overbooking (Pega o menor valor entre Dia e Período para segurança)
const overbookPermitido = Math.min(
    dayConfig?.maxOverbook ?? security?.maxOverbook ?? 0,
    periodConfig?.maxOverbook ?? security?.maxOverbook ?? 0
);

// Capacidade Total Final
let totalCapacity = baseLimit + overbookPermitido;

// Trava de Segurança Máxima (Capa o valor se houver um limite rígido configurado)
if (security?.maxPacientesPorHorario) {
    totalCapacity = Math.min(totalCapacity, security.maxPacientesPorHorario);
}
```

### 📊 Indicador de Intensidade Visual
A interface do Totem reage à ocupação através de cores e badges informativos:

*   **Verde (0% - 49%)**: Baixa ocupação.
*   **Amarelo (50% - 79%)**: Ocupação moderada (Sinal de alerta para recepção).
*   **Laranja/Vermelho (80% - 99%)**: Alta ocupação (Overbooking em uso).
*   **Cinza/Bloqueado (100%+)**: Horário lotado, botão desabilitado.

---

## 🏥 2. Gestão de Agentes e Equipe (`/admin/agents`)

### Sincronização Híbrida (Auth + Firestore)
Diferente de sistemas comuns, aqui o Agente tem uma existência dupla:
1.  **Firebase Authentication**: Credenciais de login e e-mail.
2.  **Firestore (`agents`)**: Dados operacionais, PIN de acesso rápido e métricas de carga.

### Algoritmo de Distribuição de Chamados
Ao entrar um novo paciente (via Totem ou WhatsApp), o sistema executa a **Distribuição por Menor Ocupação (`least_occupied`)**:
*   Filtra apenas agentes com status `online`.
*   Verifica se o agente está habilitado para o `queueId` (Setor) do chamado.
*   Ordena os agentes pelo número de `metrics.activeChats`.
*   Atribui o chamado ao agente com a menor carga atual.

---

## ⏳ 3. Gestão de Filas e Kanban (`/admin/queues`)

### Protocolo Manchester Digital
Cada chamado recebe uma cor baseada na prioridade:
*   🔴 **Urgent (Emergência)**: Atendimento imediato.
*   🟠 **High (Muito Urgente)**: Alerta visual piscante no monitor.
*   🟡 **Normal (Urgente)**: Fluxo padrão.
*   🟢 **Low (Pouco Urgente)**: Casos eletivos.

### Dashboard de Estatísticas
O sistema calcula em tempo real:
*   **TME (Tempo Médio de Espera)**: Diferença entre `created` e `assignedAt`.
*   **TMA (Tempo Médio de Atendimento)**: Diferença entre `assignedAt` e `resolved`.
*   **SLA Compliance**: Porcentagem de chamados atendidos dentro da meta de minutos definida para o setor.

---

## 📺 4. Monitor de Recepção (`/appointments`)

### Sistema de Chamada por Voz (TTS)
Utiliza a integração Genkit + Google Gemini para transformar texto em áudio:
*   **Lógica**: Ao clicar em "Chamar", o sistema gera um arquivo `.wav` dinâmico: *"Paciente [NOME], favor dirigir-se à [SALA] com o [MEDICO]"*.
*   **Auto-Play**: Repete o áudio 2 vezes com intervalo de 500ms para garantir que o paciente ouça.

### Auto-Rolagem Inteligente
No modo **Monitor**, o sistema calcula qual a consulta atual baseada no horário e faz um `scrollIntoView` automático, mantendo o paciente da vez sempre no centro da TV da recepção.

---

## 🤖 5. Inteligência Artificial e Reputação

### Health Score do Paciente
A IA analisa o histórico de CPF na coleção `tb_agendamentos`:
*   **Falta (No-Show)**: -25 pontos.
*   **Cancelamento Tardio**: -5 pontos.
*   **Comparecimento**: +2 pontos.
*   **Classificações**: Diamante (90+), Ouro (70+), Prata (50+), Bronze (<50).

### Diagnóstico Comportamental DeepSeek
O sistema envia o JSON do histórico do paciente para o modelo **DeepSeek V3**, que retorna um diagnóstico em Markdown sugerindo condutas (ex: *"Este paciente tem 80% de chance de faltar, exija confirmação ativa via telefone"*).
