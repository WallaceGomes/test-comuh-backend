# Web (Next.js)

Este serviço é o frontend em Next.js do projeto e roda em container Docker na porta `3001`.

## Pré-requisitos

- Docker e Docker Compose instalados
- Porta `3001` livre (web)
- API e banco do projeto em execução via `docker compose`

## Setup local

> Execute os comandos na raiz do projeto (um nível acima da pasta `web`).

1. Crie o arquivo de ambiente:

```bash
cp .env.example .env
```

2. Suba os serviços:
 - Não é necessário caso já tenha rodado `docker compose up` para a API, pois o comando abaixo sobe ambos os serviços (API e Web) juntos.

```bash
docker compose up --build
```

3. Acesse o frontend:

- http://localhost:3001

## Variáveis de ambiente relevantes

As variáveis ficam no arquivo `.env` na raiz do projeto.

- `NEXT_PUBLIC_API_BASE_URL`: URL pública usada no browser para chamadas da API (ex.: `http://localhost:3000/api/v1`)
- `API_INTERNAL_BASE_URL` (opcional): URL interna usada no server-side rendering. Se não for definida, o fallback no container é `http://api:3000/api/v1`

## Executar testes (frontend)

```bash
docker compose exec web npm run test
```

Cobertura:

```bash
docker compose exec web npm run test:coverage
```

## Lint

```bash
docker compose exec web npm run lint
```

## Execução local sem Docker (opcional)

Se quiser rodar só o frontend na máquina host:

```bash
cd web
npm install
npm run dev -- -p 3001
```

Nesse modo, garanta que a API esteja acessível em `http://localhost:3000` e configure `.env` conforme necessário.
