require "test_helper"

class Api::V1::ReactionsControllerTest < ActionDispatch::IntegrationTest
  describe "POST /api/v1/reactions" do
    it "should create reaction and return aggregated counts" do
      assert_difference "Reaction.count", 1 do
        post api_v1_reactions_url, params: {
          message_id: messages(:one).id,
          user_id: users(:two).id,
          reaction_type: "love"
        }, as: :json
      end

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal messages(:one).id, body["message_id"]
      assert_equal 1, body.dig("reactions", "like")
      assert_equal 1, body.dig("reactions", "love")
      assert_equal 0, body.dig("reactions", "insightful")
    end

    it "should return conflict when trying to duplicate reaction type for same user and message" do
      assert_no_difference "Reaction.count" do
        post api_v1_reactions_url, params: {
          message_id: messages(:one).id,
          user_id: users(:one).id,
          reaction_type: "like"
        }, as: :json
      end

      assert_response :conflict
      body = JSON.parse(response.body)
      assert_equal "Duplicate reaction for this user and message", body["error"]
    end

    it "should return unprocessable entity for invalid reaction_type" do
      assert_no_difference "Reaction.count" do
        post api_v1_reactions_url, params: {
          message_id: messages(:one).id,
          user_id: users(:one).id,
          reaction_type: "wow"
        }, as: :json
      end

      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_equal "Validation failed", body["error"]
    end
  end
end
