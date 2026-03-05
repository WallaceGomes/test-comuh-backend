require "test_helper"

class Api::V1::MessagesControllerTest < ActionDispatch::IntegrationTest
  describe "POST /api/v1/messages" do
    it "should create message and user when username does not exist" do
      with_stubbed_sentiment(return_value: 1.0) do
        assert_difference ["User.count", "Message.count"], 1 do
          post api_v1_messages_url, params: {
            username: "wallace",
            community_id: communities(:one).id,
            content: "gostei muito dessa comunidade",
            user_ip: "127.0.0.1"
          }, as: :json
        end
      end

      assert_response :created
      body = JSON.parse(response.body)
      assert_equal "wallace", body["username"]
      assert_equal communities(:one).id, body["community_id"]
      assert_equal 1.0, body["ai_sentiment_score"]
    end

    it "should create message for existing user without creating a new user" do
      with_stubbed_sentiment(return_value: 0.0) do
        assert_no_difference "User.count" do
          assert_difference "Message.count", 1 do
            post api_v1_messages_url, params: {
              username: users(:one).username,
              community_id: communities(:one).id,
              content: "mensagem normal",
              user_ip: "127.0.0.2"
            }, as: :json
          end
        end
      end

      assert_response :created
    end

    it "should return unprocessable entity when required params are missing" do
      assert_no_difference ["User.count", "Message.count"] do
        post api_v1_messages_url, params: {
          username: "novo_usuario",
          community_id: communities(:one).id,
          content: ""
        }, as: :json
      end

      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_equal "Missing required fields", body["error"]
      assert_includes body["fields"], "content"
      assert_includes body["fields"], "user_ip"
    end

    it "should create message with neutral sentiment when provider fails" do
      error = SentimentAnalyzer::ProviderError.new("AWS error")

      with_stubbed_sentiment(error: error) do
        assert_difference ["User.count", "Message.count"], 1 do
          post api_v1_messages_url, params: {
            username: "novo_usuario",
            community_id: communities(:one).id,
            content: "mensagem qualquer",
            user_ip: "127.0.0.5"
          }, as: :json
        end
      end

      assert_response :created
      body = JSON.parse(response.body)
      assert_equal 0.0, body["ai_sentiment_score"]
    end

    it "should return not found when community does not exist" do
      assert_no_difference ["User.count", "Message.count"] do
        post api_v1_messages_url, params: {
          username: "ghost-user",
          community_id: -999,
          content: "mensagem",
          user_ip: "127.0.0.9"
        }, as: :json
      end

      assert_response :not_found
      body = JSON.parse(response.body)
      assert_equal "Community not found", body["error"]
    end
  end

  private

  def with_stubbed_sentiment(return_value: nil, error: nil)
    original_call = SentimentAnalyzer.method(:call)

    SentimentAnalyzer.define_singleton_method(:call) do |_text|
      raise error if error

      return_value
    end

    yield
  ensure
    SentimentAnalyzer.define_singleton_method(:call, original_call)
  end
end
