# Seeds via HTTP (Ruby instalado)

Este diretório contém scripts Ruby para popular dados pela API (HTTP), sem inserção direta no banco.

## Pré-requisitos

- Ruby instalado na máquina (comando `ruby` disponível).
- API em execução e acessível por HTTP.
- Banco já preparado/migrado.
- Endpoint `POST /api/v1/communities` disponível na API.

## O que o seed cria

Os scripts geram dados com as seguintes regras:

- 3-5 comunidades criadas automaticamente via HTTP
- 50 usuários únicos
- 1000 mensagens
  - 700 posts principais (70%)
  - 300 comentários/respostas (30%)
- 20 IPs únicos
- 800 mensagens com pelo menos 1 reação (80%)

## Arquivos

- `seed_common.rb`: utilitários HTTP, contexto e validação de status.
- `seed_env.rb`: valida API, cria comunidades e inicializa contexto.
- `seed_01_messages.rb`: cria usuários/mensagens via `POST /api/v1/messages`.
- `seed_02_reactions.rb`: cria reações via `POST /api/v1/reactions`.
- `seed_03_validate.rb`: valida métricas e endpoints de analytics/ranking.
- `seed_all.rb`: orquestra execução de todas as etapas.

## Como executar

Na raiz do projeto:

```bash
ruby scripts/seed_all.rb
```

### Variáveis opcionais

- `BASE_URL` (default: `http://localhost:3000`)
- `SEED_TAG` (default gerado automaticamente)
- `COMMUNITIES_COUNT` (default: `3`, permitido: `3..5`)

Exemplo:

```bash
BASE_URL=http://localhost:3000 SEED_TAG=seed_manual_20260304 COMMUNITIES_COUNT=5 ruby scripts/seed_all.rb
```

## Execução passo a passo (opcional)

```bash
ruby scripts/seed_env.rb
ruby scripts/seed_01_messages.rb
ruby scripts/seed_02_reactions.rb
ruby scripts/seed_03_validate.rb
```

## Saídas esperadas

No final, o `seed_03_validate.rb` deve imprimir `OK` com métricas:

- comunidades: entre 3 e 5
- usuários: 50
- mensagens: 1000 (700 principais / 300 respostas)
- IPs únicos: 20
- mensagens com reação: >= 800

## Troubleshooting

### 1) `ruby: command not found`

Instale Ruby no host e valide com:

```bash
ruby -v
```

### 2) `Não foi possível conectar na API via HTTP`

- Confirme se a API está no ar.
- Teste manualmente:

```bash
curl -i http://localhost:3000/up
```

- Se necessário, informe `BASE_URL` explicitamente.

### 3) Falha no `POST /api/v1/communities`

Verifique se o endpoint está disponível e se `name` é único (quando usar `SEED_TAG` fixo em múltiplas execuções).

### 4) Interrupção durante execução (`Ctrl+C`)

Basta rodar novamente `ruby scripts/seed_all.rb`; os dados são regenerados com novo `SEED_TAG` por padrão.
