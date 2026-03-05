#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "seed_common"

context = SeedCommon.load_context
metrics = context.fetch("metrics")
client = SeedCommon::HttpClient.new(context.fetch("base_url"))

communities_count = context.fetch("community_ids").size
users_count = context.fetch("usernames").uniq.size
messages = context.fetch("messages")
messages_count = messages.size
root_count = messages.count { |message| message["parent_message_id"].nil? }
reply_count = messages_count - root_count
unique_ips_count = messages.map { |message| message.fetch("user_ip") }.uniq.size
reacted_messages_count = context.fetch("reacted_message_ids").uniq.size
reacted_ratio = messages_count.zero? ? 0.0 : reacted_messages_count.to_f / messages_count

status, suspicious_body = client.get("/api/v1/analytics/suspicious_ips?min_users=3")
SeedCommon.ensure_status!(status, 200, suspicious_body, "GET /api/v1/analytics/suspicious_ips")

status, top_body = client.get("/api/v1/communities/#{context.fetch('community_ids').first}/messages/top?limit=10")
SeedCommon.ensure_status!(status, 200, top_body, "GET /api/v1/communities/:id/messages/top")

errors = []
errors << "Comunidades fora da faixa 3-5: #{communities_count}" unless (metrics.fetch("min_communities")..metrics.fetch("max_communities")).cover?(communities_count)
errors << "Usuários únicos diferente de 50: #{users_count}" unless users_count == metrics.fetch("users_count")
errors << "Mensagens diferente de 1000: #{messages_count}" unless messages_count == metrics.fetch("messages_count")
errors << "Posts principais diferente de 700: #{root_count}" unless root_count == metrics.fetch("main_messages_count")
errors << "Respostas diferente de 300: #{reply_count}" unless reply_count == metrics.fetch("reply_messages_count")
errors << "IPs únicos diferente de 20: #{unique_ips_count}" unless unique_ips_count == metrics.fetch("unique_ips_count")
errors << "Mensagens com reação abaixo de 80%: #{(reacted_ratio * 100).round(2)}%" unless reacted_messages_count >= metrics.fetch("reacted_messages_count")
errors << "Ranking retornou 0 mensagens" if top_body.fetch("messages", []).empty?
errors << "Suspicious IPs retornou 0 itens" if suspicious_body.fetch("suspicious_ips", []).empty?

if errors.any?
  warn "[seed_03_validate.rb] Falhou"
  errors.each { |line| warn "  - #{line}" }
  exit 1
end

puts "[seed_03_validate.rb] OK"
puts "  - comunidades: #{communities_count}"
puts "  - usuários: #{users_count}"
puts "  - mensagens: #{messages_count} (#{root_count} principais / #{reply_count} respostas)"
puts "  - IPs únicos: #{unique_ips_count}"
puts "  - mensagens com reação: #{reacted_messages_count} (#{(reacted_ratio * 100).round(2)}%)"