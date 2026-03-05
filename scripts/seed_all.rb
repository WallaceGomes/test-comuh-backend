#!/usr/bin/env ruby
# frozen_string_literal: true

script_dir = __dir__

steps = [
  "seed_env.rb",
  "seed_01_messages.rb",
  "seed_02_reactions.rb",
  "seed_03_validate.rb"
]

steps.each do |file|
  path = File.join(script_dir, file)
  puts "[seed_all.rb] Executando #{file} (HTTP)"
  success = system("ruby", path)
  raise "Falha ao executar #{file}" unless success
end

puts "[seed_all.rb] Seed HTTP concluído com sucesso"