require "test_helper"
require "ostruct"

class SentimentAnalyzerTest < ActiveSupport::TestCase
  describe ".call" do
    it "should return neutral score when text is blank" do
      assert_equal 0.0, SentimentAnalyzer.call(nil)
      assert_equal 0.0, SentimentAnalyzer.call("")
      assert_equal 0.0, SentimentAnalyzer.call("   ")
    end

    it "should map provider labels to expected scores" do
      captured_args = nil
      fake_client = Object.new
      fake_client.define_singleton_method(:detect_sentiment) do |text:, language_code:|
        captured_args = { text: text, language_code: language_code }
        OpenStruct.new(sentiment: "POSITIVE")
      end

      SentimentAnalyzer.stub(:client, fake_client) do
        assert_equal 1.0, SentimentAnalyzer.call("bom")
      end

      assert_equal({ text: "bom", language_code: "pt" }, captured_args)
    end

    it "should fallback to neutral for unknown label" do
      captured_args = nil
      fake_client = Object.new
      fake_client.define_singleton_method(:detect_sentiment) do |text:, language_code:|
        captured_args = { text: text, language_code: language_code }
        OpenStruct.new(sentiment: "UNKNOWN")
      end

      SentimentAnalyzer.stub(:client, fake_client) do
        assert_equal 0.0, SentimentAnalyzer.call("texto")
      end

      assert_equal({ text: "texto", language_code: "pt" }, captured_args)
    end

    it "should raise provider error when aws client fails" do
      service_error = Aws::Comprehend::Errors::ServiceError.new(nil, "aws unavailable")
      captured_args = nil
      fake_client = Object.new
      fake_client.define_singleton_method(:detect_sentiment) do |text:, language_code:|
        captured_args = { text: text, language_code: language_code }
        raise service_error
      end

      SentimentAnalyzer.stub(:client, fake_client) do
        error = assert_raises(SentimentAnalyzer::ProviderError) { SentimentAnalyzer.call("texto") }
        assert_match(/AWS Comprehend sentiment analysis failed/, error.message)
      end

      assert_equal({ text: "texto", language_code: "pt" }, captured_args)
    end
  end
end
