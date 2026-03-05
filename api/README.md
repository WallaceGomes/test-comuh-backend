# API (Rails)

Este serviço é a API Ruby on Rails do projeto e roda em container Docker.

## Pré-requisitos

- Docker e Docker Compose instalados
- Porta `3000` livre (API)
- Porta `5432` livre (PostgreSQL)

## Setup local

> Execute os comandos na raiz do projeto (um nível acima da pasta `api`).

1. Crie o arquivo de ambiente:

```bash
cp .env.example .env
```

2. Suba os serviços:

```bash
docker compose up --build
```

3. Em outro terminal, prepare o banco da API:

```bash
docker compose exec api rails db:prepare
```

4. Verifique se a API está no ar:

```bash
curl -i http://localhost:3000/up
```

## Executar testes (backend)

```bash
docker compose exec api rails test
```

## Endpoints da API

A documentação dos endpoints está em:

- `api/API_ENDPOINTS.md`

## Collection Postman

Existe uma collection do Postman no projeto para facilitar testes manuais da API:

- `api/API_ENDPOINTS.postman_collection.json`

Para usar:

1. Importe o arquivo no Postman.
2. Defina a variável `host` (ex.: `http://localhost:3000`).

## Popular dados de exemplo (seed)

O arquivo `api/db/seeds.rb` está vazio neste projeto. Para popular dados de exemplo, use os scripts HTTP da pasta `scripts/` na raiz:

```bash
ruby scripts/seed_all.rb
```

Pré-condições para o seed HTTP:

- API em execução (`docker compose up`)
- Ruby disponível no host para executar os scripts (`ruby -v`)

## Decisões técnicas

- **Rails API + PostgreSQL**: escolha por familiaridade e produtividade, validações nativas, Active Record e consultas SQL eficientes para ranking e analytics.
- **Containerização com Docker Compose**: padroniza ambiente local (API, Web e banco), reduz diferenças entre máquinas e simplifica setup.
- **Sentimento com fallback resiliente**: `POST /api/v1/messages` usa AWS Comprehend (familiaridade pois já utilizei), mas em indisponibilidade do provedor a mensagem ainda é criada com score neutro (`0.0`).
- **Concorrência em reações**: proteção contra duplicidade por usuário/mensagem/tipo com validação e tratamento de conflitos (`409`).
- **Paginação e limites defensivos**: endpoint de top mensagens normaliza `limit/offset` (`limit` entre 1 e 50, `offset` mínimo 0) para previsibilidade e segurança.
- **Testes automatizados com Minitest**: cobertura de controllers, models e serviços para contratos de API, validações, erros e regras de negócio.

## Variáveis de ambiente relevantes

As variáveis ficam no arquivo `.env` na raiz do projeto.

Banco de dados:

- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`
- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `DATABASE_URL`

AWS Comprehend:

- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Frontend -> API:

- `NEXT_PUBLIC_API_BASE_URL`

## Sentiment analysis (AWS Comprehend)

O sentimento da mensagem é analisado no `POST /api/v1/messages` usando AWS Comprehend.

Comportamento:

- `POSITIVE` => `1.0`
- `NEGATIVE` => `-1.0`
- `NEUTRAL`/`MIXED` => `0.0`
- Em falha na AWS, a criação da mensagem continua e grava `0.0`.
