require "test_helper"
require "securerandom"

class Api::V1::CommunitiesControllerTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  describe "GET /api/v1/communities/:id/messages/top" do
    it "should return top messages ordered by engagement score" do
      suffix = SecureRandom.hex(4)
      community = Community.create!(name: "test-ranking-#{suffix}", description: "Ranking")
      user_one = User.create!(username: "test-alice-#{suffix}")
      user_two = User.create!(username: "test-bob-#{suffix}")
      user_three = User.create!(username: "test-charlie-#{suffix}")

      higher_score_message = Message.create!(
        user: user_one,
        community: community,
        content: "test-Mensagem A",
        user_ip: "10.1.0.1",
        ai_sentiment_score: 0.3
      )
      lower_score_message = Message.create!(
        user: user_two,
        community: community,
        content: "test-Mensagem B",
        user_ip: "10.1.0.2",
        ai_sentiment_score: 0.1
      )

      Reaction.create!(message: higher_score_message, user: user_one, reaction_type: "like")
      Message.create!(
        user: user_two,
        community: community,
        parent_message: higher_score_message,
        content: "test-Resposta 1",
        user_ip: "10.1.0.3",
        ai_sentiment_score: 0.0
      )
      Message.create!(
        user: user_three,
        community: community,
        parent_message: higher_score_message,
        content: "test-Resposta 2",
        user_ip: "10.1.0.4",
        ai_sentiment_score: 0.0
      )

      Reaction.create!(message: lower_score_message, user: user_one, reaction_type: "like")
      Reaction.create!(message: lower_score_message, user: user_two, reaction_type: "love")

      get "/api/v1/communities/#{community.id}/messages/top", as: :json

      assert_equal 200, response.status, response.body
      body = JSON.parse(response.body)
      assert_equal higher_score_message.id, body["messages"].first["id"]
      assert_equal 1, body["messages"].first["reaction_count"]
      assert_equal 2, body["messages"].first["reply_count"]
      assert_equal user_one.username, body["messages"].first.dig("user", "username")
      assert_not_nil body["messages"].first["created_at"]
    end

    it "should apply max limit of 50" do
      suffix = SecureRandom.hex(4)
      community = Community.create!(name: "test-limit-#{suffix}", description: "Limit")
      user = User.create!(username: "test-limit-user-#{suffix}")

      60.times do |index|
        Message.create!(
          user: user,
          community: community,
          content: "test-limit-message-#{index}",
          user_ip: "10.2.0.#{(index % 250) + 1}",
          ai_sentiment_score: 0.0
        )
      end

      get "/api/v1/communities/#{community.id}/messages/top", params: { limit: 999 }

      assert_response :ok
      body = JSON.parse(response.body)
      assert_operator body["messages"].size, :<=, 50
    end

    it "should fallback to default limit when limit is not provided" do
      suffix = SecureRandom.hex(4)
      community = Community.create!(name: "test-default-limit-#{suffix}", description: "Limit")
      user = User.create!(username: "test-default-limit-user-#{suffix}")

      15.times do |index|
        Message.create!(
          user: user,
          community: community,
          content: "test-default-limit-message-#{index}",
          user_ip: "10.3.0.#{(index % 250) + 1}",
          ai_sentiment_score: 0.0
        )
      end

      get "/api/v1/communities/#{community.id}/messages/top"

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal 10, body["messages"].size
    end

    it "should normalize negative limit to one" do
      suffix = SecureRandom.hex(4)
      community = Community.create!(name: "test-negative-limit-#{suffix}", description: "Limit")
      user = User.create!(username: "test-negative-limit-user-#{suffix}")

      5.times do |index|
        Message.create!(
          user: user,
          community: community,
          content: "test-negative-limit-message-#{index}",
          user_ip: "10.4.0.#{(index % 250) + 1}",
          ai_sentiment_score: 0.0
        )
      end

      get "/api/v1/communities/#{community.id}/messages/top", params: { limit: -3 }

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal 1, body["messages"].size
    end

    it "should paginate messages with offset" do
      suffix = SecureRandom.hex(4)
      community = Community.create!(name: "test-offset-#{suffix}", description: "Offset")
      user = User.create!(username: "test-offset-user-#{suffix}")

      first_message = Message.create!(
        user: user,
        community: community,
        content: "test-offset-message-1",
        user_ip: "10.5.0.1",
        ai_sentiment_score: 0.0
      )
      second_message = Message.create!(
        user: user,
        community: community,
        content: "test-offset-message-2",
        user_ip: "10.5.0.2",
        ai_sentiment_score: 0.0
      )

      get "/api/v1/communities/#{community.id}/messages/top", params: { limit: 1, offset: 1 }

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal 1, body["messages"].size
      assert_equal first_message.id, body["messages"].first["id"]
      assert_equal 1, body.dig("pagination", "offset")
      assert_equal 2, body.dig("pagination", "next_offset")
      assert_equal false, body.dig("pagination", "has_more")
      assert_equal 2, body.dig("pagination", "total")
      assert_equal second_message.id, Message.where(community: community).order(created_at: :desc).first.id
    end

    it "should normalize negative offset to zero" do
      suffix = SecureRandom.hex(4)
      community = Community.create!(name: "test-negative-offset-#{suffix}", description: "Offset")
      user = User.create!(username: "test-negative-offset-user-#{suffix}")

      Message.create!(
        user: user,
        community: community,
        content: "test-negative-offset-message-1",
        user_ip: "10.6.0.1",
        ai_sentiment_score: 0.0
      )
      second_message = Message.create!(
        user: user,
        community: community,
        content: "test-negative-offset-message-2",
        user_ip: "10.6.0.2",
        ai_sentiment_score: 0.0
      )

      get "/api/v1/communities/#{community.id}/messages/top", params: { limit: 1, offset: -10 }

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal second_message.id, body["messages"].first["id"]
      assert_equal 0, body.dig("pagination", "offset")
    end

    it "should return not found when community does not exist" do
      get "/api/v1/communities/999999/messages/top", as: :json

      assert_response :not_found
      body = JSON.parse(response.body)
      assert_equal "Community not found", body["error"]
    end
  end
end
