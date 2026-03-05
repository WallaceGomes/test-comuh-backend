class Api::V1::MessagesController < ApplicationController
	def create
		payload = message_payload
		missing_fields = required_fields.select { |field| payload[field].blank? }
		if missing_fields.any?
			return render json: { error: "Missing required fields", fields: missing_fields }, status: :unprocessable_entity
		end

		community = Community.find(payload[:community_id])
		sentiment_score = begin
			SentimentAnalyzer.call(payload[:content])
		rescue SentimentAnalyzer::ProviderError => error
			Rails.logger.warn("Sentiment analyzer unavailable: #{error.message}")
			0.0
		end

		user = find_or_create_user!(payload[:username])
		message = Message.create!(
			user: user,
			community: community,
			parent_message_id: payload[:parent_message_id],
			content: payload[:content],
			user_ip: payload[:user_ip],
			ai_sentiment_score: sentiment_score
		)

		render json: serialize_message(message), status: :created
	rescue ActiveRecord::RecordNotFound
		render json: { error: "Community not found" }, status: :not_found
	rescue ActiveRecord::RecordInvalid => error
		render json: { error: "Validation failed", details: error.record.errors.full_messages }, status: :unprocessable_entity
	rescue ActiveRecord::RecordNotUnique
		user = User.find_by!(username: payload[:username])
		retry_message = Message.create!(
			user: user,
			community_id: payload[:community_id],
			parent_message_id: payload[:parent_message_id],
			content: payload[:content],
			user_ip: payload[:user_ip],
			ai_sentiment_score: sentiment_score
		)
		render json: serialize_message(retry_message), status: :created
	end

	private

	def message_payload
		params.permit(:username, :community_id, :parent_message_id, :content, :user_ip)
	end

	def required_fields
		%i[username community_id content user_ip]
	end

	def find_or_create_user!(username)
		User.find_or_create_by!(username: username)
	rescue ActiveRecord::RecordNotUnique
		User.find_by!(username: username)
	end

	def serialize_message(message)
		{
			id: message.id,
			username: message.user.username,
			community_id: message.community_id,
			parent_message_id: message.parent_message_id,
			content: message.content,
			user_ip: message.user_ip,
			ai_sentiment_score: message.ai_sentiment_score,
			created_at: message.created_at
		}
	end
end
