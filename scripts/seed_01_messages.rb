#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "seed_common"

context = SeedCommon.load_context
rng = Random.new
client = SeedCommon::HttpClient.new(context.fetch("base_url"))

metrics = context.fetch("metrics")
main_target = metrics.fetch("main_messages_count")
reply_target = metrics.fetch("reply_messages_count")

community_ids = context.fetch("community_ids")
usernames = context.fetch("usernames")
ips = context.fetch("ips")
seed_tag = context.fetch("seed_tag")

messages = []
main_messages = []

themes = [
  {
    title: "onboarding de novos membros",
    issue: "muita gente entra e não sabe por onde começar",
    action: "criar uma trilha curta com 3 passos",
    metric: "tempo até primeira contribuição"
  },
  {
    title: "qualidade das discussões",
    issue: "alguns tópicos ficam repetitivos",
    action: "incentivar resumo semanal com links úteis",
    metric: "taxa de respostas úteis"
  },
  {
    title: "organização de eventos da comunidade",
    issue: "nem sempre os horários atendem todo mundo",
    action: "alternar horários e publicar agenda com antecedência",
    metric: "presença média por evento"
  },
  {
    title: "documentação compartilhada",
    issue: "conteúdo bom se perde em conversas antigas",
    action: "manter uma página de decisões e boas práticas",
    metric: "número de consultas na documentação"
  },
  {
    title: "moderação e convivência",
    issue: "algumas interações ficam ríspidas",
    action: "reforçar regras de convivência com exemplos práticos",
    metric: "queda de reports por conflito"
  },
  {
    title: "feedback em pull requests",
    issue: "reviews demoram e bloqueiam entregas",
    action: "definir SLA por tipo de mudança",
    metric: "tempo médio de aprovação"
  },
  {
    title: "boas práticas com Ruby on Rails",
    issue: "padrões de código variam muito entre times",
    action: "publicar guia com exemplos reais do projeto",
    metric: "redução de retrabalho em revisão"
  },
  {
    title: "integração entre API e frontend",
    issue: "campos mudam sem aviso e quebram telas",
    action: "adotar checklist de contrato antes do deploy",
    metric: "incidentes por incompatibilidade"
  },
  {
    title: "performance das consultas",
    issue: "algumas páginas ficaram lentas com mais dados",
    action: "mapear queries críticas e adicionar índices",
    metric: "tempo p95 de resposta"
  },
  {
    title: "adoção de testes automatizados",
    issue: "bugs simples ainda chegam em produção",
    action: "priorizar testes para fluxos de maior risco",
    metric: "taxa de regressão por release"
  }
].freeze

main_openers = [
  "Pessoal, queria abrir uma conversa sobre",
  "Tenho observado um ponto importante em",
  "Queria ouvir a opinião de vocês sobre",
  "Nos últimos dias notei oportunidades em"
].freeze

reply_openers = [
  "Concordo com esse ponto.",
  "Boa provocação.",
  "Faz sentido olhar por esse lado.",
  "Gostei da proposta."
].freeze

generate_main_content = lambda do |index|
  theme = themes[index % themes.size]
  opener = main_openers[index % main_openers.size]
  "#{seed_tag} | #{opener} #{theme[:title]}. " \
    "Hoje o principal problema é que #{theme[:issue]}. " \
    "Uma ação prática seria #{theme[:action]}. " \
    "Se der certo, podemos medir pelo indicador de #{theme[:metric]}."
end

generate_reply_content = lambda do |index, parent|
  opener = reply_openers[index % reply_openers.size]
  parent_content = parent.fetch("content")
  excerpt = parent_content.split("|", 2).last&.strip || parent_content
  "#{seed_tag} | #{opener} Acho que vale começar com um piloto pequeno. " \
    "No post você trouxe: '#{excerpt[0..120]}'. " \
    "Se alinharmos responsáveis e prazo, fica mais fácil acompanhar resultado."
end

create_message = lambda do |payload|
  status, body = client.post_json("/api/v1/messages", payload)
  SeedCommon.ensure_status!(status, 201, body, "POST /api/v1/messages")
  body
end

capture_user_ids = lambda do
  community_id = community_ids.first
  status, body = client.get("/api/v1/communities/#{community_id}/messages/top?limit=50")
  SeedCommon.ensure_status!(status, 200, body, "GET /api/v1/communities/:id/messages/top")

  map = {}
  body.fetch("messages", []).each do |message|
    user = message.fetch("user", {})
    username = user["username"]
    user_id = user["id"]
    next if username.nil? || user_id.nil?

    map[username] = user_id
  end
  map
end

usernames.each_with_index do |username, index|
  content = generate_main_content.call(index)
  payload = {
    username: username,
    community_id: community_ids.first,
    content: content,
    user_ip: ips[index % ips.size]
  }

  body = create_message.call(payload)
  message = {
    "id" => body.fetch("id"),
    "community_id" => body.fetch("community_id"),
    "parent_message_id" => body["parent_message_id"],
    "username" => body.fetch("username"),
    "user_ip" => body.fetch("user_ip"),
    "content" => body.fetch("content")
  }
  main_messages << message
  messages << message
end

context["user_ids_by_username"] = capture_user_ids.call
if context["user_ids_by_username"].size < metrics.fetch("users_count")
  raise "Não foi possível capturar IDs dos 50 usuários via HTTP. Capturados: #{context['user_ids_by_username'].size}."
end

(main_target - usernames.size).times do |index|
  username = usernames.sample(random: rng)
  community_id = community_ids.sample(random: rng)
  content = generate_main_content.call(index + usernames.size)
  payload = {
    username: username,
    community_id: community_id,
    content: content,
    user_ip: ips[(index + usernames.size) % ips.size]
  }

  body = create_message.call(payload)
  message = {
    "id" => body.fetch("id"),
    "community_id" => body.fetch("community_id"),
    "parent_message_id" => body["parent_message_id"],
    "username" => body.fetch("username"),
    "user_ip" => body.fetch("user_ip"),
    "content" => body.fetch("content")
  }
  main_messages << message
  messages << message
end

reply_target.times do |index|
  parent = main_messages.sample(random: rng)
  username = usernames.sample(random: rng)
  content = generate_reply_content.call(index, parent)
  payload = {
    username: username,
    community_id: parent.fetch("community_id"),
    parent_message_id: parent.fetch("id"),
    content: content,
    user_ip: ips[(index + main_target) % ips.size]
  }

  body = create_message.call(payload)
  messages << {
    "id" => body.fetch("id"),
    "community_id" => body.fetch("community_id"),
    "parent_message_id" => body["parent_message_id"],
    "username" => body.fetch("username"),
    "user_ip" => body.fetch("user_ip"),
    "content" => body.fetch("content")
  }
end

context["messages"] = messages
context["message_ids"] = messages.map { |item| item.fetch("id") }
context["main_message_ids"] = messages.filter { |item| item["parent_message_id"].nil? }.map { |item| item.fetch("id") }
context["reply_message_ids"] = messages.filter { |item| !item["parent_message_id"].nil? }.map { |item| item.fetch("id") }

SeedCommon.write_context(context)

puts "[seed_01_messages.rb] Mensagens criadas via HTTP"
puts "  - total: #{context['message_ids'].size}"
puts "  - principais: #{context['main_message_ids'].size}"
puts "  - respostas: #{context['reply_message_ids'].size}"
puts "  - user_ids capturados: #{context['user_ids_by_username'].size}"