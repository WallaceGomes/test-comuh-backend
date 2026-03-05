class Api::V1::AnalyticsController < ApplicationController
	def suspicious_ips
		min_users = normalized_min_users

		rows = Message.joins(:user)
			.group(:user_ip)
			.having("COUNT(DISTINCT messages.user_id) >= ?", min_users)
			.order(Arel.sql("COUNT(DISTINCT messages.user_id) DESC, messages.user_ip ASC"))
			.pluck(
				:user_ip,
				Arel.sql("COUNT(DISTINCT messages.user_id)"),
				Arel.sql("ARRAY_AGG(DISTINCT users.username ORDER BY users.username)")
			)

		render json: {
			suspicious_ips: rows.map do |ip, user_count, usernames|
				{
					ip: ip,
					user_count: user_count.to_i,
					usernames: usernames
				}
			end
		}
	end

	private

	def normalized_min_users
		min_users = params[:min_users].presence&.to_i || 3
		min_users.positive? ? min_users : 3
	end
end
