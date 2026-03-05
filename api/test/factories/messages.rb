FactoryBot.define do
  factory :message do
    association :user
    association :community
    content { "Mensagem de teste" }
    user_ip { Constants::USER_IP }
    ai_sentiment_score { 0.0 }
  end
end
