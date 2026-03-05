require "simplecov"
require "uri"

SimpleCov.start "rails" do
  enable_coverage :branch
  primary_coverage :branch
  track_files "app/**/*.rb"
  add_filter "/test/"

  add_group "Controllers", "app/controllers"
  add_group "Models", "app/models"
  add_group "Services", "app/services"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
end

require "minitest/autorun"
require "shoulda/matchers"
require "factory_bot_rails"
require "webmock/minitest"
require "spy/integration"
require "jsonpath"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "shoulda-context"

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |file| require file }

URI(ENV.fetch("ELASTICSEARCH_URL", "http://localhost:9200")).tap do |uri|
  WebMock.disable_net_connect!(allow: ["#{uri.host}:#{uri.port}", "http.cat", "localhost", "127.0.0.1"])
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    include FactoryBot::Syntax::Methods
    include EnvironmentHelper
    include GeneralHelper
    include ActionCable::TestHelper if defined?(ActionCable::TestHelper)
    extend ::Minitest::Spec::DSL

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      Searchkick.disable_callbacks if defined?(Searchkick)
    end

    teardown do
      Rails.cache.clear
    end

    def assert_shoulda_matcher(matcher, subject)
      assert matcher.matches?(subject), matcher.failure_message
    end

    # Add more helper methods to be used by all tests here...
  end
end
