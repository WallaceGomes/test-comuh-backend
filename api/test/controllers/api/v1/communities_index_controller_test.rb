require "test_helper"

class Api::V1::CommunitiesIndexControllerTest < ActionDispatch::IntegrationTest
  describe "GET /api/v1/communities" do
    it "should return communities list with message counts" do
      get api_v1_communities_url, as: :json

      assert_response :ok
      body = JSON.parse(response.body)
      assert body["communities"].is_a?(Array)

      ruby_community = body["communities"].find { |community| community["name"] == "ruby" }
      nextjs_community = body["communities"].find { |community| community["name"] == "nextjs" }

      assert_not_nil ruby_community
      assert_not_nil nextjs_community

      assert_equal 1, ruby_community["messages_count"]
      assert_equal 1, nextjs_community["messages_count"]
    end
  end
end
