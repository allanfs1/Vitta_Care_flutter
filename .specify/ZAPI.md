# Z-API Collection — Documentação Completa

> **Fonte**: Coleção Postman "Z-API Collection" (Fork de Allan Ferreira de Souza)
> **Documentação oficial**: [https://developer.z-api.io/](https://developer.z-api.io/)

## O que é Z-API?

**Z-API** é um serviço RESTful que provê uma API para interagir com o WhatsApp de forma programática. Permite enviar e receber mensagens, gerenciar instâncias, grupos, comunidades e muito mais — tudo via chamadas HTTP simples.

---

## Variáveis de Ambiente

Todas as requisições utilizam as seguintes variáveis Postman:

| Variável | Descrição | Exemplo |
|---|---|---|
| `BASE_URL` | URL base da API | `https://api.z-api.io` |
| `INSTANCE_ID` | ID da sua instância Z-API | `3C67AB1234...` |
| `INSTANCE_TOKEN` | Token de autenticação da instância | `abc123def456...` |
| `CLIENT_TOKEN` | Token do cliente (enviado no header) | `F1a2b3c4d5...` |
| `PARTNER_AUTH_TOKEN` | Token de parceiro (para API de Partners) | `xyz789...` |

### Padrão de URL Base

Todas as rotas seguem o padrão:
```
https://api.z-api.io/instances/{INSTANCE_ID}/token/{INSTANCE_TOKEN}/{endpoint}
```

### Header Obrigatório

Todas as requisições exigem o header:
```
Client-Token: {CLIENT_TOKEN}
```

---

## 📌 Instance — Pegar QR Code (Conexão do Aparelho)

> **Função Principal**: Conectar um número de telefone à instância Z-API via leitura de QR Code no WhatsApp do celular.

Uma **instância** é uma conexão entre um número de telefone (com conta WhatsApp) e os servidores da Z-API. Antes de enviar ou receber qualquer mensagem, o número precisa ser conectado à instância. Isso é feito através da leitura de um QR Code gerado pela API — similar ao processo de conectar o WhatsApp Web.

### Pegar QRCode — Bytes

Retorna os bytes brutos do QR Code para renderização em um componente compatível com sua linguagem.

| Campo | Valor |
|---|---|
| **Método** | `GET` |
| **Endpoint** | `/instances/{INSTANCE_ID}/token/{INSTANCE_TOKEN}/qr-code` |

**cURL:**
```bash
curl --request GET \
  --url 'https://api.z-api.io/instances/{INSTANCE_ID}/token/{INSTANCE_TOKEN}/qr-code' \
  --header 'Client-Token: {CLIENT_TOKEN}'
```

**Resposta**: Retorna os bytes do QR Code. Renderize em um componente QR Code da sua linguagem.

---

### Pegar QRCode — Imagem (Base64)

Retorna uma imagem Base64 do QR Code pronta para renderizar em uma tag `<img>`.

| Campo | Valor |
|---|---|
| **Método** | `GET` |
| **Endpoint** | `/instances/{INSTANCE_ID}/token/{INSTANCE_TOKEN}/qr-code/image` |

**cURL:**
```bash
curl --request GET \
  --url 'https://api.z-api.io/instances/{INSTANCE_ID}/token/{INSTANCE_TOKEN}/qr-code/image' \
  --header 'Client-Token: {CLIENT_TOKEN}'
```

**Resposta**: Retorna uma string Base64 da imagem do QR Code. Use em `<img src="data:image/png;base64,{RESPOSTA}" />`.

---

### Pegar QRCode — Telefone (Código Numérico)

Retorna um código numérico que pode ser usado para conectar o número **sem leitura de QR Code**. O código é inserido diretamente no WhatsApp, na aba de "Conectar com número de telefone".

| Campo | Valor |
|---|---|
| **Método** | `GET` |
| **Endpoint** | `/instances/{INSTANCE_ID}/token/{INSTANCE_TOKEN}/phone-code/{PHONE_NUMBER}` |
| **Parâmetro de path** | `{PHONE_NUMBER}` — Número a conectar (ex: `5511999999999`) |

**cURL:**
```bash
curl --request GET \
  --url 'https://api.z-api.io/instances/{INSTANCE_ID}/token/{INSTANCE_TOKEN}/phone-code/5511999999999' \
  --header 'Client-Token: {CLIENT_TOKEN}'
```

---

## 📌 Instance — Minha Instância

### Status da Instância

Verifica se a instância está conectada a uma conta WhatsApp.

| Campo | Valor |
|---|---|
| **Método** | `GET` |
| **Endpoint** | `.../status` |

### Reiniciar Instância

Reinicia a instância (útil em caso de problemas de conexão).

| Campo | Valor |
|---|---|
| **Método** | `GET` |
| **Endpoint** | `.../restart` |

### Desconectar Instância

Desconecta o número do Z-API.

| Campo | Valor |
|---|---|
| **Método** | `GET` |
| **Endpoint** | `.../disconnect` |

### Dados da Instância

Retorna informações completas sobre a instância conectada.

| Campo | Valor |
|---|---|
| **Método** | `GET` |
| **Endpoint** | `.../me` |

### Renomear Instância

| Campo | Valor |
|---|---|
| **Método** | `PUT` |
| **Endpoint** | `.../update-name` |
| **Body** | `{ "value": "Novo nome" }` |

---

## 📌 Instance — Configurações

### Leitura Automática

Ativa/desativa a leitura automática de mensagens recebidas.

| Campo | Valor |
|---|---|
| **Método** | `PUT` |
| **Endpoint** | `.../update-auto-read-message` |
| **Body** | `{ "value": true }` |

### Rejeitar Chamadas

Ativa/desativa a rejeição automática de chamadas de voz.

| Campo | Valor |
|---|---|
| **Método** | `PUT` |
| **Endpoint** | `.../update-call-reject-auto` |
| **Body** | `{ "value": true }` |

### Mensagem de Rejeição de Ligação

Define a mensagem enviada automaticamente ao rejeitar uma chamada.

| Campo | Valor |
|---|---|
| **Método** | `PUT` |
| **Endpoint** | `.../update-call-reject-message` |
| **Body** | `{ "value": "Mensagem de resposta" }` |

### Dados do Celular

Retorna informações sobre o dispositivo conectado.

| Campo | Valor |
|---|---|
| **Método** | `GET` |
| **Endpoint** | `.../device` |

---

## 📩 Messages — Endpoints de Envio

> Todos os endpoints de mensagem usam **método POST** e recebem JSON no body.

### Enviar Texto Simples

Envia texto puro. Suporta formatação do WhatsApp e emojis.

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-text` |

```json
{
  "phone": "554499999999",
  "message": "Olá! Esta é uma mensagem de teste.",
  "delayMessage": 15
  // "delayTyping": 0
  // "editMessageId": ""
}
```

| Parâmetro | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `phone` | string | ✅ | Número do destinatário (DDI+DDD+número) |
| `message` | string | ✅ | Texto da mensagem |
| `delayMessage` | number | ❌ | Atraso em segundos antes de enviar |
| `delayTyping` | number | ❌ | Tempo simulando "digitando..." |
| `editMessageId` | string | ❌ | ID da mensagem a ser editada |

---

### Enviar Imagem

Envia imagens via URL ou Base64.

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-image` |

```json
{
  "phone": "5544999999999",
  "image": "https://app.z-api.io/logos/zapi-dark.png"
  // "caption": "Legenda da imagem",
  // "messageId": "",
  // "delayMessage": 5,
  // "viewOnce": ""
}
```

---

### Enviar Áudio

Envia áudio (como mensagem de voz) via URL ou Base64.

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-audio` |

```json
{
  "phone": "5544999999999",
  "audio": "https://exemplo.com/audio.mp3"
  // "delayMessage": 5,
  // "delayTyping": 5,
  // "viewOnce": ""
}
```

---

### Enviar Vídeo

Envia vídeos via URL ou Base64.

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-video` |

```json
{
  "phone": "5544999999999",
  "video": "https://exemplo.com/video.mp4"
  // "caption": "",
  // "messageId": "",
  // "delayMessage": 5,
  // "viewOnce": ""
}
```

---

### Enviar Documento

Envia qualquer tipo de documento. A extensão deve ser informada na URL.

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-document/{EXTENSAO}` |

```json
{
  "phone": "5544999999999",
  "document": "https://exemplo.com/arquivo.pdf"
  // "fileName": "relatorio.pdf",
  // "caption": "",
  // "delayMessage": 5
}
```

---

### Enviar Sticker

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-sticker` |

```json
{
  "phone": "5544999999999",
  "sticker": "https://exemplo.com/sticker.png"
  // "stickerAuthor": "Nome do autor"
}
```

---

### Enviar GIF

O arquivo deve ser formato **MP4**.

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-gif` |

```json
{
  "phone": "5544999999999",
  "gif": "https://exemplo.com/animacao.mp4"
  // "caption": ""
}
```

---

### Enviar PTV (Video View Once)

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-ptv` |

```json
{
  "phone": "5544999999999",
  "ptv": "https://exemplo.com/video.mp4"
}
```

---

### Enviar Link (com preview)

Envia um link com imagem de preview, título e descrição.

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-link` |

```json
{
  "phone": "5544999999999",
  "message": "Confira nosso site!",
  "image": "https://app.z-api.io/logos/zapi-dark.png",
  "linkUrl": "https://app.z-api.io",
  "title": "Z-API",
  "linkDescription": "Integração WhatsApp"
  // "linkType": "SMALL"
}
```

---

### Enviar Localização

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-location` |

```json
{
  "phone": "5544999999999",
  "title": "Agenda Clínica",
  "address": "Av. Brg. Faria Lima, 3477 - São Paulo",
  "latitude": "-23.0696347",
  "longitude": "-50.4357913"
}
```

---

### Enviar Contato

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-contact` |

```json
{
  "phone": "5544999999999",
  "contactName": "Dr. João Silva",
  "contactPhone": "554488888888"
  // "contactBusinessDescription": ""
}
```

---

### Enviar Vários Contatos

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-contacts` |

```json
{
  "phone": "5544999999999",
  "contacts": [
    { "name": "Contato 1", "phones": ["5544999999999"] },
    { "name": "Contato 2", "phones": ["5544888888888"], "businessDescription": "Empresa X" }
  ]
}
```

---

### Enviar Texto com Botões de Ação

Envia mensagem com botões de ação (ligar, abrir URL).

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-button-actions` |

```json
{
  "phone": "554499999999",
  "message": "Como podemos ajudar?",
  "title": "Título opcional",
  "footer": "Rodapé opcional",
  "buttonActions": [
    { "id": "1", "type": "CALL", "phone": "5544998887777", "label": "Fale conosco" },
    { "id": "2", "type": "URL", "url": "https://z-api.io", "label": "Visite nosso site" }
  ]
}
```

---

### Enviar Texto com Botões de Resposta

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-button-list` |

```json
{
  "phone": "554499999999",
  "message": "Deseja confirmar a consulta?",
  "buttonList": {
    "buttons": [
      { "id": "1", "label": "Sim, confirmo" },
      { "id": "2", "label": "Reagendar" }
    ]
  }
}
```

---

### Enviar Botões com Imagem

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-button-list` |

```json
{
  "phone": "554499999999",
  "message": "Escolha uma opção:",
  "buttonList": {
    "image": "https://exemplo.com/imagem.png",
    "buttons": [
      { "id": "1", "label": "Opção A" },
      { "id": "2", "label": "Opção B" }
    ]
  }
}
```

---

## 📩 Messages — Operações Avançadas

### Reencaminhar Mensagem

| Campo | Valor |
|---|---|
| **Endpoint** | `.../forward-message` |

```json
{
  "phone": "554498744288",
  "messageId": "3EB06DD33E37863E4EA421",
  "messagePhone": "554499999999"
}
```

### Enviar / Remover Reação

| Ação | Endpoint |
|---|---|
| Enviar reação | `.../send-reaction` |
| Remover reação | `.../send-remove-reaction` |

```json
{
  "phone": "5544999999999",
  "reaction": "😋",
  "messageId": "3EB06DD33E37863E4EA421"
}
```

### Deletar Mensagens

| Campo | Valor |
|---|---|
| **Endpoint** | `.../delete-message` |

### Ler Mensagens

| Campo | Valor |
|---|---|
| **Endpoint** | `.../read-message` |

### Responder Mensagem

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-reply` |

### Enviar Enquete / Votação

| Ação | Endpoint |
|---|---|
| Criar enquete | `.../send-poll` |
| Votar | `.../send-poll-vote` |

### Fixar / Desafixar Mensagem

| Campo | Valor |
|---|---|
| **Endpoint** | `.../pin-message` |

### Enviar Produto / Catálogo (Business)

| Ação | Endpoint |
|---|---|
| Enviar produto | `.../send-product` |
| Enviar catálogo | `.../send-catalog` |

### Botão OTP / PIX

| Ação | Endpoint |
|---|---|
| Botão OTP | `.../send-otp-button` |
| Botão PIX | `.../send-pix-button` |

### Enviar Lista de Opções

| Campo | Valor |
|---|---|
| **Endpoint** | `.../send-option-list` |

### Eventos

| Ação | Endpoint |
|---|---|
| Enviar evento | `.../send-event` |
| Editar evento | `.../edit-event` |
| Responder evento | `.../respond-event` |

---

## 🔒 Privacy (Privacidade)

Configurações de privacidade da conta do WhatsApp vinculada.

| Configuração | Endpoint (GET / PUT) | Descrição |
|---|---|---|
| **Visto por último / Online** | `.../privacy-online` | Define quem pode ver "visto por último" e status "online" |
| **Foto de perfil** | `.../privacy-profile-pic` | Define quem pode ver a foto do perfil |
| **Recado (About)** | `.../privacy-status` | Define quem pode ver o recado |
| **Confirmação de Leitura** | `.../privacy-read-receipts` | Ativa/desativa os tickets azuis de leitura |

*Valores aceitos para as configurações:* `all` (Todos), `contacts` (Meus Contatos), `contact_blacklist` (Meus contatos, exceto...), `none` (Ninguém).

---

## 👥 Contacts (Contatos)

Gerenciamento da lista de contatos do celular conectado.

| Ação | Método | Endpoint |
|---|---|---|
| **Buscar contatos** | `GET` | `.../contacts` (Lista todos os contatos com paginação) |
| **Metadata do contato** | `GET` | `.../contacts/{PHONE_NUMBER}` |
| **Validar contato** | `GET` | `.../contacts-exists/{PHONE_NUMBER}` (Verifica se possui WhatsApp) |
| **Bloquear contato** | `POST` | `.../block-contact` |
| **Desbloquear contato** | `POST` | `.../unblock-contact` |
| **Imagem do contato** | `GET` | `.../profile-picture?phone={PHONE_NUMBER}` |

---

## 💬 Chats (Conversas)

Operações diretas nas conversas (chats individuais ou grupos).

| Ação | Método | Endpoint |
|---|---|---|
| **Listar conversas** | `GET` | `.../chats` |
| **Metadata da conversa** | `GET` | `.../chats/{PHONE_NUMBER}` |
| **Ler conversa** | `POST` | `.../read-chat` (Marca a conversa inteira como lida) |
| **Arquivar conversa** | `POST` | `.../archive-chat` |
| **Fixar conversa** | `POST` | `.../pin-chat` |
| **Mutar conversa** | `POST` | `.../mute-chat` (Tempo configurável no body) |
| **Limpar conversa** | `POST` | `.../clear-chat` (Apaga as mensagens, mantém o chat) |
| **Deletar conversa** | `DELETE` | `.../delete-chat/{PHONE_NUMBER}` |

---

## 📞 Calls (Ligações)

| Ação | Método | Endpoint |
|---|---|---|
| **Fazer Ligação** | `POST` | `.../calls` (Inicia uma chamada de voz para o número informado) |

---

## 👨‍👩‍👦 Groups (Grupos)

Gerenciamento completo de grupos de WhatsApp. O "phone" de um grupo geralmente possui o formato `{ID}-group` ou similar (ex: `5511999999999-162327528`).

| Ação | Método | Endpoint |
|---|---|---|
| **Criar grupo** | `POST` | `.../create-group` (Requer nome e array de participantes) |
| **Listar grupos** | `GET` | `.../groups` |
| **Adicionar participante** | `POST` | `.../add-participant-group` |
| **Remover participante** | `POST` | `.../remove-participant-group` |
| **Promover admin** | `POST` | `.../add-admin` |
| **Remover admin** | `POST` | `.../remove-admin` |
| **Sair do grupo** | `POST` | `.../leave-group` |
| **Metadata do grupo** | `GET` | `.../group-metadata/{GROUP_PHONE_NUMBER}` |
| **Redefinir link de convite** | `POST` | `.../redefine-invitation-link/{GROUP_PHONE_NUMBER}` |
| **Configurações do grupo** | `POST` | `.../update-group-settings` (Somente admins mandam msg, aprovação, etc) |
| **Mencionar membro** | `POST` | `.../send-text` (Usando o array `mentioned` no body) |

---

## 🏢 Communities (Comunidades)

As comunidades reúnem vários grupos sob um único guarda-chuva.

| Ação | Método | Endpoint |
|---|---|---|
| **Criar comunidade** | `POST` | `.../communities` |
| **Listar comunidades** | `GET` | `.../communities` |
| **Metadata** | `GET` | `.../communities-metadata/{COMMUNITY_ID}` |
| **Vincular grupos** | `POST` | `.../communities/link` |
| **Desvincular grupos** | `POST` | `.../communities/unlink` |
| **Adicionar participante** | `POST` | `.../add-participant` |
| **Promover admin** | `POST` | `.../add-admin-community` |

---

## 📰 Newsletter (Canais)

Canais do WhatsApp para transmissão unidirecional de conteúdo.

| Ação | Método | Endpoint |
|---|---|---|
| **Criar canal** | `POST` | `.../newsletter` |
| **Listar canais** | `GET` | `.../newsletter` |
| **Metadata do canal** | `GET` | `.../newsletter-metadata/{NEWSLETTER_ID}` |
| **Seguir / Deixar de seguir** | `POST` | `.../newsletter/follow` ou `.../newsletter/unfollow` |
| **Mutar / Desmutar** | `POST` | `.../newsletter/mute` ou `.../newsletter/unmute` |
| **Deletar canal** | `DELETE` | `.../newsletter/{NEWSLETTER_ID}` |

---

## 🕒 Status

Publicar status do WhatsApp (que duram 24 horas).

| Ação | Método | Endpoint |
|---|---|---|
| **Enviar texto status** | `POST` | `.../send-text-status` |
| **Enviar imagem status** | `POST` | `.../send-image-status` |

---

## 🚦 Message Queue (Fila de Mensagens)

A Z-API usa um sistema de filas para ordenar as mensagens e entregá-las caso o celular perca conexão.

| Ação | Método | Endpoint |
|---|---|---|
| **Ver fila** | `GET` | `.../queue` |
| **Apagar fila inteira** | `DELETE` | `.../queue` |
| **Apagar mensagem específica** | `DELETE` | `.../queue/{MESSAGE_ID}` |

---

## 🏪 WhatsApp Business

APIs exclusivas para números do WhatsApp Business.

### Produtos e Catálogo
- **Criar/Editar Produto**: `POST .../products`
- **Buscar Produtos**: `GET .../catalogs` (Meu catálogo) ou `.../catalogs/{PHONE}` (Catálogo de terceiros)
- **Deletar Produto**: `DELETE .../products/{PRODUCT_ID}`
- **Coleções**: endpoints para listar, criar e adicionar produtos a coleções (`.../catalogs/collection`).

### Etiquetas (Tags)
- **Buscar etiquetas**: `GET .../tags`
- **Criar/Editar/Deletar etiqueta**: Endpoints em `.../business/create-tag`, `.../business/edit-tag/{ID}`, etc.
- **Atribuir etiqueta a chat**: `PUT .../chats/{PHONE_NUMBER}/tags/{TAG_ID}/add`

### Perfil da Empresa
Gerenciamento de descrição (`company-description`), e-mail (`company-email`), endereço (`company-address`), websites (`company-websites`) e horários de funcionamento (`hours`).

---

## 🪝 Webhooks

Endpoints para configurar as URLs do seu sistema que receberão os eventos da Z-API via POST.

| Tipo de Webhook | Endpoint para Atualizar a URL | Descrição |
|---|---|---|
| **Ao receber mensagem** | `PUT .../update-webhook-received` | URL chamada quando chega uma nova mensagem. |
| **Ao enviar mensagem** | `PUT .../update-webhook-delivery` | URL chamada para confirmar entrega (Delivery). |
| **Status da mensagem** | `PUT .../update-webhook-message-status` | URL chamada quando a mensagem é lida, entregue, etc. |
| **Conexão/Desconexão** | `PUT .../update-webhook-connected` (e `disconnected`) | Notifica queda ou sucesso de conexão da instância. |

---

## 🤝 Partners (Parceiros Integradores)

APIs para parceiros gerenciarem suas instâncias "on-demand" diretamente. (Requer `PARTNER_AUTH_TOKEN`).

| Ação | Endpoint |
|---|---|
| **Criar Instância** | `POST {{BASE_URL}}/instances/integrator/on-demand` |
| **Assinar Instância** | `POST .../integrator/on-demand/subscription` |
| **Cancelar Instância** | `POST .../integrator/on-demand/cancel` |
| **Listar Instâncias** | `GET {{BASE_URL}}/instances` (com filtros) |

---

## Estrutura Completa das Pastas da Coleção

```
Z-API Collection/
├── Instance/
│   ├── Meu perfil/ (Atualizar nome, imagem, descrição)
│   ├── Ligações/ (Rejeitar chamadas, mensagem de ligação)
│   ├── Pegar QRCode/ (bytes, imagem, telefone) ← CONEXÃO
│   ├── Minha instância/ (Reiniciar, desconectar, status, dados)
│   ├── Leitura automática
│   └── Dados do celular
├── Mobile/
│   ├── Registro do dispositivo/ (Verificar, solicitar código, captcha, confirmar)
│   ├── Código PIN/ (Confirmar, recuperar, verificar, cadastrar, remover)
│   ├── Email/ (Buscar, cadastrar, verificar, remover)
│   └── Desbanimento/ (Solicitar)
├── Messages/ ← ENVIO DE MENSAGENS
│   ├── Enviar texto simples
│   ├── Reencaminhar mensagem
│   ├── Enviar/Remover reação
│   ├── Enviar imagem / sticker / GIF / áudio / vídeo / PTV
│   ├── Enviar documentos
│   ├── Enviar link / localização / contato(s)
│   ├── Enviar produto / catálogo
│   ├── Botões de ação / Botões de resposta / Botões com imagem/vídeo
│   ├── Lista de opções / Botão OTP / Botão PIX
│   ├── Deletar / Ler / Responder mensagem
│   ├── Enviar enquete / Enviar voto
│   ├── Aprovação / Status / Pagamento de pedidos
│   ├── Fixar/Desafixar mensagens
│   └── Eventos (enviar, editar, responder)
├── Privacy/ (Visto por último, foto, recado, online, leitura)
├── Contacts/ (Listar, metadata, imagem, validar número, bloquear)
├── Chats/ (Listar, metadata, ler, arquivar, fixar, mutar, limpar, deletar)
├── Calls/ (Fazer ligação)
├── Groups/ (CRUD completo de grupos)
├── Communities/ (CRUD de comunidades)
├── Newsletter/ (Canais: criar, seguir, admin, deletar)
├── Status/ (Texto e imagem para status)
├── Message Queue/ (Ver fila, apagar fila, apagar mensagem da fila)
├── WhatsApp Business/ (Produtos, Etiquetas, Coleção, Perfil, Categorias)
├── Webhooks/ (Ao enviar, ao receber, ao desconectar, conectar, status)
└── Partners/ (Criar, assinar, cancelar, listar instâncias)
```
