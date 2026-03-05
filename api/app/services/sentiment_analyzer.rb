class SentimentAnalyzer
  class ProviderError < StandardError; end

  SENTIMENT_SCORE_BY_LABEL = {
    "POSITIVE" => 1.0,
    "NEGATIVE" => -1.0,
    "NEUTRAL" => 0.0,
    "MIXED" => 0.0
  }.freeze

  LANGUAGE_CODE = "pt".freeze

  def self.call(text)
    return 0.0 if text.blank?

    response = client.detect_sentiment(
      text: text.to_s,
      language_code: LANGUAGE_CODE
    )

    SENTIMENT_SCORE_BY_LABEL.fetch(response.sentiment, 0.0)
  rescue Aws::Comprehend::Errors::ServiceError => error
    raise ProviderError, "AWS Comprehend sentiment analysis failed: #{error.message}"
  end

  def self.client
    @client ||= Aws::Comprehend::Client.new(region: ENV.fetch("AWS_REGION"))
  end
end
