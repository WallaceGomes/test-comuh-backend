#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "uri"

module SeedCommon
  module_function

  CONTEXT_PATH = File.expand_path(".seed_context.json", __dir__)

  DEFAULTS = {
    "communities_count" => 3,
    "users_count" => 50,
    "messages_count" => 1000,
    "main_messages_count" => 700,
    "reply_messages_count" => 300,
    "unique_ips_count" => 20,
    "reacted_messages_count" => 800,
    "min_communities" => 3,
    "max_communities" => 5
  }.freeze

  class HttpClient
    def initialize(base_url)
      @base_uri = URI(base_url)
    end

    def get(path)
      request(Net::HTTP::Get.new(uri_for(path)))
    end

    def post_json(path, payload)
      request_uri = uri_for(path)
      request = Net::HTTP::Post.new(request_uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      request(request)
    end

    private

    def uri_for(path)
      URI.join(@base_uri.to_s.end_with?("/") ? @base_uri.to_s : "#{@base_uri}/", path.sub(%r{\A/}, ""))
    end

    def request(req)
      Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: req.uri.scheme == "https") do |http|
        response = http.request(req)
        body = parse_json(response.body)
        [response.code.to_i, body]
      end
    end

    def parse_json(raw)
      return {} if raw.nil? || raw.strip.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      { "raw" => raw }
    end
  end

  def load_context
    raise "Contexto não encontrado em #{CONTEXT_PATH}. Rode scripts/seed_env.rb." unless File.exist?(CONTEXT_PATH)

    JSON.parse(File.read(CONTEXT_PATH))
  end

  def write_context(data)
    File.write(CONTEXT_PATH, JSON.pretty_generate(data))
  end

  def base_url
    ENV.fetch("BASE_URL", "http://localhost:3000")
  end

  def seed_tag
    ENV.fetch("SEED_TAG", "http_seed_#{Time.now.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(3)}")
  end

  def seed_name_prefix(seed_tag_value = seed_tag)
    custom_prefix = ENV["SEED_NAME_PREFIX"]
    return custom_prefix.downcase.gsub(/[^a-z0-9]/, "")[0, 12] unless custom_prefix.nil? || custom_prefix.strip.empty?

    cleaned = seed_tag_value.downcase.gsub(/[^a-z0-9]/, "")
    cleaned = SecureRandom.hex(3) if cleaned.empty?
    cleaned[0, 12]
  end

  def generated_ips
    (1..DEFAULTS.fetch("unique_ips_count")).map { |index| "10.240.0.#{index}" }
  end

  def ensure_status!(status, expected, body, action)
    return if status == expected

    raise "#{action} falhou (HTTP #{status}, esperado #{expected}): #{JSON.generate(body)}"
  end
end