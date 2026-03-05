class Api::V1::CommunitiesController < ApplicationController
	def create
		payload = community_payload
		if payload[:name].blank?
			return render json: { error: "Missing required fields", fields: ["name"] }, status: :unprocessable_entity
		end

		community = Community.create!(payload)

		render json: {
			id: community.id,
			name: community.name,
			description: community.description,
			messages_count: 0
		}, status: :created
	rescue ActiveRecord::RecordInvalid => error
		render json: { error: "Validation failed", details: error.record.errors.full_messages }, status: :unprocessable_entity
	end

	def index
		communities = Community
			.left_joins(:messages)
			.select("communities.id", "communities.name", "communities.description", "COUNT(messages.id) AS messages_count")
			.group("communities.id")
			.order("communities.name ASC")

		render json: {
			communities: communities.map do |community|
				{
					id: community.id,
					name: community.name,
					description: community.description,
					messages_count: community.messages_count.to_i
				}
			end
		}
	end

	def top_messages
		community = Community.find(params[:id])
		limit = normalized_limit
		offset = normalized_offset

		reaction_count_sql = "(SELECT COUNT(*) FROM reactions WHERE reactions.message_id = messages.id)"
		reply_count_sql = "(SELECT COUNT(*) FROM messages replies WHERE replies.parent_message_id = messages.id)"
		engagement_score_sql = "((#{reaction_count_sql}) * 1.5 + (#{reply_count_sql}) * 1.0)"

		messages = community.messages
			.joins(:user)
			.select(
				"messages.id",
				"messages.content",
				"messages.ai_sentiment_score",
				"messages.created_at",
				"users.id AS author_id",
				"users.username AS author_username",
				"#{reaction_count_sql} AS reaction_count",
				"#{reply_count_sql} AS reply_count",
				"#{engagement_score_sql} AS engagement_score"
			)
			.order(Arel.sql("#{engagement_score_sql} DESC, messages.created_at DESC"))
			.offset(offset)
			.limit(limit)

		total_messages = community.messages.count
		next_offset = offset + messages.size

		render json: {
			messages: messages.map { |message| serialize_top_message(message) },
			pagination: {
				limit: limit,
				offset: offset,
				next_offset: next_offset,
				has_more: next_offset < total_messages,
				total: total_messages
			}
		}
	rescue ActiveRecord::RecordNotFound
		render json: { error: "Community not found" }, status: :not_found
	end

	private

	def community_payload
		params.permit(:name, :description)
	end

	def normalized_limit
		requested_limit = params[:limit].presence&.to_i || 10
		requested_limit = 1 if requested_limit < 1
		[requested_limit, 50].min
	end

	def normalized_offset
		requested_offset = params[:offset].presence&.to_i || 0
		requested_offset.negative? ? 0 : requested_offset
	end

	def serialize_top_message(message)
		{
			id: message.id,
			content: message.content,
			created_at: message.created_at,
			user: {
				id: message.author_id,
				username: message.author_username
			},
			ai_sentiment_score: message.ai_sentiment_score,
			reaction_count: message.reaction_count.to_i,
			reply_count: message.reply_count.to_i,
			engagement_score: message.engagement_score.to_f.round(2)
		}
	end
end
