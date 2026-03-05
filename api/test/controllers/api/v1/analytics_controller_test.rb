require "test_helper"
require "securerandom"

class Api::V1::AnalyticsControllerTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    host! "localhost"
  end

  describe "GET /api/v1/analytics/suspicious_ips" do
    it "should return suspicious ips with default min_users 3" do
      suffix = SecureRandom.hex(4)
      community = Community.create!(name: "test-analytics-#{suffix}", description: "Analytics")
      user_one = User.create!(username: "test-user-1-#{suffix}")
      user_two = User.create!(username: "test-user-2-#{suffix}")
      user_three = User.create!(username: "test-user-3-#{suffix}")

      [user_one, user_two, user_three].each_with_index do |user, index|
        Message.create!(
          user: user,
          community: community,
          content: "test-msg-#{index}",
          user_ip: "192.168.10.10",
          ai_sentiment_score: 0.0
        )
      end

      get api_v1_analytics_suspicious_ips_url, as: :json

      assert_equal 200, response.status, response.body
      body = JSON.parse(response.body)
      entry = body["suspicious_ips"].find { |item| item["ip"] == "192.168.10.10" }
      assert_not_nil entry
      assert_equal 3, entry["user_count"]
      assert_includes entry["usernames"], user_one.username
      assert_includes entry["usernames"], user_two.username
      assert_includes entry["usernames"], user_three.username
    end

    it "should apply custom min_users filter" do
      suffix = SecureRandom.hex(4)
      community = Community.create!(name: "test-analytics-filter-#{suffix}", description: "Analytics")
      user_one = User.create!(username: "test-filter-1-#{suffix}")
      user_two = User.create!(username: "test-filter-2-#{suffix}")
      user_three = User.create!(username: "test-filter-3-#{suffix}")

      Message.create!(user: user_one, community: community, content: "a", user_ip: "10.10.10.10", ai_sentiment_score: 0.0)
      Message.create!(user: user_two, community: community, content: "b", user_ip: "10.10.10.10", ai_sentiment_score: 0.0)
      Message.create!(user: user_one, community: community, content: "c", user_ip: "10.10.20.20", ai_sentiment_score: 0.0)
      Message.create!(user: user_two, community: community, content: "d", user_ip: "10.10.20.20", ai_sentiment_score: 0.0)
      Message.create!(user: user_three, community: community, content: "e", user_ip: "10.10.20.20", ai_sentiment_score: 0.0)

      get "/api/v1/analytics/suspicious_ips", params: { min_users: 3 }

      assert_response :ok
      body = JSON.parse(response.body)
      ips = body["suspicious_ips"].map { |item| item["ip"] }
      assert_includes ips, "10.10.20.20"
      assert_not_includes ips, "10.10.10.10"
    end

    it "should fallback to default min_users when min_users is zero" do
      suffix = SecureRandom.hex(4)
      community = Community.create!(name: "test-analytics-zero-#{suffix}", description: "Analytics")
      user_one = User.create!(username: "test-zero-1-#{suffix}")
      user_two = User.create!(username: "test-zero-2-#{suffix}")

      Message.create!(user: user_one, community: community, content: "a", user_ip: "10.11.10.10", ai_sentiment_score: 0.0)
      Message.create!(user: user_two, community: community, content: "b", user_ip: "10.11.10.10", ai_sentiment_score: 0.0)

      get "/api/v1/analytics/suspicious_ips", params: { min_users: 0 }

      assert_response :ok
      body = JSON.parse(response.body)
      ips = body["suspicious_ips"].map { |item| item["ip"] }
      assert_not_includes ips, "10.11.10.10"
    end
  end
end
