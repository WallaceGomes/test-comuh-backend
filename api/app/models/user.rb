class User < ApplicationRecord
	has_many :messages, dependent: :nullify
	has_many :reactions, dependent: :nullify

	validates :username, presence: true, uniqueness: true
end
