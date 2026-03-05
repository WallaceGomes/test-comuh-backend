## ✅ Checklist de Entrega - [Wallace Cardoso Gomes]

### Repositório & Código
- [x ] Código no GitHub (público): [URL DO REPO]
- [x ] README com instruções completas
- [x ] `.env.example` ou similar com variáveis de ambiente
- [x ] Linter/formatter configurado
- [x ] Código limpo e organizado
### Stack Utilizada
- [x ] Backend: [Ruby on Rails]
- [x ] Frontend: [NextJS]
- [x ] Banco de dados: [PostgreSQL]
- [x ] Testes: [Minitest, Vitest]
### Deploy
- [x ] URL da aplicação: [[URL](https://test-comuh-backend.vercel.app/)]
- [x ] Seeds executados (dados de exemplo visíveis)
### Funcionalidades - API
- [x ] POST /api/v1/messages (criar mensagem + sentiment)
- [x ] POST /api/v1/reactions (com proteção de concorrência)
- [x ] GET /api/v1/communities/:id/messages/top
- [x ] GET /api/v1/analytics/suspicious_ips
- [x ] Tratamento de erros apropriado
- [x ] Validações implementadas
### Funcionalidades - Frontend
- [x ] Listagem de comunidades
- [x ] Timeline de mensagens
- [x ] Criar mensagem (sem reload)
- [x ] Reagir a mensagens (sem reload)
- [x ] Ver thread de comentários
- [x ] Responsivo (mobile + desktop)
### Testes
- [x ] Cobertura mínima de 70%
- [x ] Testes passando
- [x ] Como rodar:
    - Backend: `docker compose exec api rails test`
    - Frontend: `docker compose exec web npm run test`
### Documentação
- [x ] Setup local documentado
- [x ] Decisões técnicas explicadas
- [x ] Como rodar seeds
- [x ] Endpoints da API documentados
- [ ] Screenshot ou GIF da interface (opcional)
### ⏰ Entregue em: 05/03/2026