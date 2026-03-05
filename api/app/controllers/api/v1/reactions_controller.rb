class Api::V1::ReactionsController < ApplicationController
	def create
		payload = reaction_payload
		missing_fields = required_fields.select { |field| payload[field].blank? }
		if missing_fields.any?
			return render json: { error: "Missing required fields", fields: missing_fields }, status: :unprocessable_entity
		end

		message = Message.find(payload[:message_id])
		user = User.find(payload[:user_id])

		Reaction.create!(
			message: message,
			user: user,
			reaction_type: payload[:reaction_type]
		)

		render json: {
			message_id: message.id,
			reactions: reactions_count_for(message)
		}, status: :ok
	rescue ActiveRecord::RecordNotFound => error
		render json: { error: error.model == "Message" ? "Message not found" : "User not found" }, status: :not_found
	rescue ActiveRecord::RecordNotUnique
		render json: { error: "Duplicate reaction for this user and message" }, status: :conflict
	rescue ActiveRecord::RecordInvalid => error
		if duplicate_reaction_validation?(error)
			render json: { error: "Duplicate reaction for this user and message" }, status: :conflict
		else
			render json: { error: "Validation failed", details: error.record.errors.full_messages }, status: :unprocessable_entity
		end
	end

	private

	def reaction_payload
		params.permit(:message_id, :user_id, :reaction_type)
	end

	def required_fields
		%i[message_id user_id reaction_type]
	end

	def reactions_count_for(message)
		counts = message.reactions.group(:reaction_type).count
		{
			like: counts.fetch("like", 0),
			love: counts.fetch("love", 0),
			insightful: counts.fetch("insightful", 0)
		}
	end

	def duplicate_reaction_validation?(error)
		error.record.errors.of_kind?(:reaction_type, :taken)
	end
end
