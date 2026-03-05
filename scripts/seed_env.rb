#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "seed_common"

preferred_base_url = SeedCommon.base_url
candidate_base_urls = [preferred_base_url]
candidate_base_urls << "http://api:3000" if preferred_base_url == "http://localhost:3000"

resolved_base_url = nil
client = nil

candidate_base_urls.each do |candidate|
  begin
    candidate_client = SeedCommon::HttpClient.new(candidate)
    status, _ = candidate_client.get("/up")
    next unless status == 200

    resolved_base_url = candidate
    client = candidate_client
    break
  rescue StandardError
    next
  end
end

raise "Não foi possível conectar na API via HTTP. Tentativas: #{candidate_base_urls.join(', ')}" if client.nil?

communities_count = Integer(ENV.fetch("COMMUNITIES_COUNT", SeedCommon::DEFAULTS.fetch("communities_count")))
unless (SeedCommon::DEFAULTS.fetch("min_communities")..SeedCommon::DEFAULTS.fetch("max_communities")).cover?(communities_count)
  raise "COMMUNITIES_COUNT inválido: #{communities_count}. Use um valor entre 3 e 5."
end

community_ids = []
seed_tag = SeedCommon.seed_tag
seed_name_prefix = SeedCommon.seed_name_prefix(seed_tag)
communities_count.times do |index|
  payload = {
    name: format("%<prefix>s_c%<i>02d", prefix: seed_name_prefix, i: index + 1),
    description: "Comunidade criada automaticamente pelo seed HTTP (#{index + 1})"
  }

  status, body = client.post_json("/api/v1/communities", payload)
  SeedCommon.ensure_status!(status, 201, body, "POST /api/v1/communities")
  community_ids << body.fetch("id")
end

usernames = (1..SeedCommon::DEFAULTS.fetch("users_count")).map do |index|
  format("%<prefix>s_u%<i>03d", prefix: seed_name_prefix, i: index)
end

context = {
  "base_url" => resolved_base_url,
  "seed_tag" => seed_tag,
  "community_ids" => community_ids,
  "community_count" => community_ids.size,
  "usernames" => usernames,
  "user_ids_by_username" => {},
  "ips" => SeedCommon.generated_ips,
  "messages" => [],
  "message_ids" => [],
  "main_message_ids" => [],
  "reply_message_ids" => [],
  "reacted_message_ids" => [],
  "metrics" => SeedCommon::DEFAULTS
}

SeedCommon.write_context(context)

puts "[seed_env.rb] Contexto HTTP preparado"
puts "  - base_url: #{context['base_url']}"
puts "  - comunidades criadas: #{context['community_count']}"
puts "  - usuários planejados: #{context['usernames'].size}"
puts "  - IPs únicos planejados: #{context['ips'].uniq.size}"