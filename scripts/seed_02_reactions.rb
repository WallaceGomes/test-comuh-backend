#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "seed_common"

context = SeedCommon.load_context
rng = Random.new
client = SeedCommon::HttpClient.new(context.fetch("base_url"))

message_ids = context.fetch("message_ids")
user_ids = context.fetch("user_ids_by_username").values
reaction_types = %w[like love insightful]

required_reacted_messages = context.fetch("metrics").fetch("reacted_messages_count")
reacted_message_ids = message_ids.sample(required_reacted_messages, random: rng)

attempted_keys = {}
reacted_success = []

reacted_message_ids.each do |message_id|
  created = false

  12.times do
    user_id = user_ids.sample(random: rng)
    reaction_type = reaction_types.sample(random: rng)
    key = "#{message_id}-#{user_id}-#{reaction_type}"
    next if attempted_keys[key]

    attempted_keys[key] = true

    status, body = client.post_json(
      "/api/v1/reactions",
      { message_id: message_id, user_id: user_id, reaction_type: reaction_type }
    )

    if status == 200
      reacted_success << message_id
      created = true
      break
    end

    next if status == 409

    raise "POST /api/v1/reactions falhou (HTTP #{status}): #{JSON.generate(body)}"
  end

  raise "Não foi possível criar reação para a mensagem #{message_id}." unless created
end

context["reacted_message_ids"] = reacted_success.uniq
SeedCommon.write_context(context)

puts "[seed_02_reactions.rb] Reações criadas via HTTP"
puts "  - mensagens com reação: #{context['reacted_message_ids'].size}"