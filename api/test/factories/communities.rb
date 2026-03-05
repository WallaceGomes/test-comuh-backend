FactoryBot.define do
  factory :community do
    sequence(:name) { |n| "Comunidade #{n}" }
    description { "Descrição da comunidade" }
  end
end
