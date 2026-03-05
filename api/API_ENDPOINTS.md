# Documentação de Endpoints da API

## Base URL

- Endpoints versionados (`/api/v1`): `http://localhost:3000/api/v1`
- Endpoint de healthcheck (sem prefixo): `http://localhost:3000/up`

## Healthcheck

### GET `/up`

Endpoint de saúde da aplicação Rails.

> Este endpoint **não** usa o prefixo `/api/v1`.

**Exemplo**

```bash
curl -X GET "http://localhost:3000/up"
```

**Resposta (200)**

```json
{
  "status": "ok"
}
```

---

## Comunidades

### GET `/communities`

Lista comunidades com total de mensagens por comunidade.

**Exemplo**

```bash
curl -X GET "http://localhost:3000/api/v1/communities"
```

**Resposta (200)**

```json
{
  "communities": [
    {
      "id": 1,
      "name": "ruby",
      "description": "Comunidade Ruby",
      "messages_count": 10
    }
  ]
}
```

### POST `/communities`

Cria uma nova comunidade.

**Body (JSON)**

- `name` (string, obrigatório, único)
- `description` (string, opcional)

**Exemplo**

```bash
curl -X POST "http://localhost:3000/api/v1/communities" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rails",
    "description": "Comunidade Ruby on Rails"
  }'
```

**Resposta (201)**

```json
{
  "id": 2,
  "name": "rails",
  "description": "Comunidade Ruby on Rails",
  "messages_count": 0
}
```

**Erros**

- `422 Unprocessable Entity` (campos obrigatórios ausentes)

```json
{
  "error": "Missing required fields",
  "fields": ["name"]
}
```

- `422 Unprocessable Entity` (falha de validação, ex.: nome já existente)

```json
{
  "error": "Validation failed",
  "details": ["Name has already been taken"]
}
```

---

## Mensagens

### POST `/messages`

Cria uma mensagem e calcula sentimento via AWS Comprehend.

**Body (JSON)**

- `username` (string, obrigatório)
- `community_id` (integer, obrigatório)
- `content` (string, obrigatório)
- `user_ip` (string, obrigatório)
- `parent_message_id` (integer, opcional) — para comentário/resposta

**Exemplo**

```bash
curl -X POST "http://localhost:3000/api/v1/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "wallace",
    "community_id": 1,
    "content": "Gostei muito dessa comunidade",
    "user_ip": "127.0.0.1"
  }'
```

**Resposta (201)**

```json
{
  "id": 10,
  "username": "wallace",
  "community_id": 1,
  "parent_message_id": null,
  "content": "Gostei muito dessa comunidade",
  "user_ip": "127.0.0.1",
  "ai_sentiment_score": 1.0,
  "created_at": "2026-03-04T21:00:00.000Z"
}
```

**Erros**

- `422 Unprocessable Entity` (campos obrigatórios ausentes)

```json
{
  "error": "Missing required fields",
  "fields": ["content", "user_ip"]
}
```

- `404 Not Found` (comunidade inexistente)

```json
{
  "error": "Community not found"
}
```

- `422 Unprocessable Entity` (outras validações)

```json
{
  "error": "Validation failed",
  "details": ["..."]
}
```

**Observação de fallback de sentimento**

Se o provedor de sentimento falhar, a mensagem ainda é criada com `ai_sentiment_score = 0.0`.

---

## Reações

### POST `/reactions`

Registra reação de um usuário em uma mensagem e retorna contagem agregada por tipo.

**Body (JSON)**

- `message_id` (integer, obrigatório)
- `user_id` (integer, obrigatório)
- `reaction_type` (string, obrigatório): `like`, `love`, `insightful`

**Exemplo**

```bash
curl -X POST "http://localhost:3000/api/v1/reactions" \
  -H "Content-Type: application/json" \
  -d '{
    "message_id": 10,
    "user_id": 2,
    "reaction_type": "love"
  }'
```

**Resposta (200)**

```json
{
  "message_id": 10,
  "reactions": {
    "like": 1,
    "love": 2,
    "insightful": 0
  }
}
```

**Erros**

- `404 Not Found` (mensagem ou usuário não encontrado)

```json
{
  "error": "Message not found"
}
```

ou

```json
{
  "error": "User not found"
}
```

- `409 Conflict` (reação duplicada para mesmo usuário/mensagem/tipo)

```json
{
  "error": "Duplicate reaction for this user and message"
}
```

- `422 Unprocessable Entity` (tipo inválido ou campos ausentes)

```json
{
  "error": "Validation failed",
  "details": ["Reaction type is not included in the list"]
}
```

ou

```json
{
  "error": "Missing required fields",
  "fields": ["reaction_type"]
}
```

---

## Ranking de mensagens por comunidade

### GET `/communities/:id/messages/top`

Retorna mensagens da comunidade ordenadas por engajamento com paginação.

**Query params**

- `limit` (opcional, default `10`, min `1`, max `50`)
- `offset` (opcional, default `0`, negativo é normalizado para `0`)

**Fórmula de engajamento**

`engagement_score = reaction_count * 1.5 + reply_count * 1.0`

Ordenação:

1. `engagement_score` desc
2. `created_at` desc

**Exemplo**

```bash
curl -X GET "http://localhost:3000/api/v1/communities/1/messages/top?limit=10&offset=0"
```

**Resposta (200)**

```json
{
  "messages": [
    {
      "id": 10,
      "content": "Mensagem exemplo",
      "created_at": "2026-03-04T21:10:00.000Z",
      "user": {
        "id": 2,
        "username": "wallace"
      },
      "ai_sentiment_score": 0.0,
      "reaction_count": 3,
      "reply_count": 1,
      "engagement_score": 5.5
    }
  ],
  "pagination": {
    "limit": 10,
    "offset": 0,
    "next_offset": 1,
    "has_more": false,
    "total": 1
  }
}
```

**Erros**

- `404 Not Found` (comunidade inexistente)

```json
{
  "error": "Community not found"
}
```

---

## Analytics

### GET `/analytics/suspicious_ips`

Retorna IPs que foram usados por múltiplos usuários distintos.

**Query params**

- `min_users` (opcional, default `3`; se `<= 0`, usa `3`)

**Exemplo**

```bash
curl -X GET "http://localhost:3000/api/v1/analytics/suspicious_ips?min_users=3"
```

**Resposta (200)**

```json
{
  "suspicious_ips": [
    {
      "ip": "192.168.10.10",
      "user_count": 3,
      "usernames": ["alice", "bob", "carol"]
    }
  ]
}
```
