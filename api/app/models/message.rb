class Message < ApplicationRecord
  belongs_to :user
  belongs_to :community
  belongs_to :parent_message, class_name: "Message", optional: true

  has_many :replies,
    class_name: "Message",
    foreign_key: :parent_message_id,
    dependent: :nullify,
    inverse_of: :parent_message
  has_many :reactions, dependent: :destroy

  validates :content, presence: true
  validates :user_ip, presence: true
end
