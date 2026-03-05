# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
	default_allowed_origins = [
		"http://localhost:3001",
		"http://127.0.0.1:3001",
		%r{\Ahttp://192\.168\.\d+\.\d+:3001\z}
	]

	configured_allowed_origins = ENV.fetch("FRONTEND_ALLOWED_ORIGINS", "")
		.split(",")
		.map(&:strip)
		.reject(&:empty?)

	allowed_origins = default_allowed_origins + configured_allowed_origins

	if ENV["CORS_ALLOW_VERCEL_PREVIEWS"] == "true"
		vercel_project_slug = ENV.fetch("CORS_VERCEL_PROJECT_SLUG", "").strip

		if vercel_project_slug.empty?
			allowed_origins << %r{\Ahttps://[a-z0-9-]+\.vercel\.app\z}
		else
			allowed_origins << %r{\Ahttps://#{Regexp.escape(vercel_project_slug)}(?:-[a-z0-9-]+)*\.vercel\.app\z}
		end
	end

	allow do
		origins(*allowed_origins)

		resource "*",
			headers: :any,
			methods: %i[get post put patch delete options head]
	end
end
