require "test_helper"
require "securerandom"

class Api::V1::CommunitiesCreateControllerTest < ActionDispatch::IntegrationTest
  test "creates community with valid payload" do
    assert_difference "Community.count", 1 do
      post api_v1_communities_url, params: {
        name: "elixir-#{SecureRandom.hex(3)}",
        description: "Comunidade Elixir"
      }, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["id"].present?
    assert body["name"].present?
    assert_equal 0, body["messages_count"]
  end

  test "returns unprocessable entity when name is missing" do
    assert_no_difference "Community.count" do
      post api_v1_communities_url, params: {
        description: "Sem nome"
      }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "Missing required fields", body["error"]
    assert_includes body["fields"], "name"
  end
end