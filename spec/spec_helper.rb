# frozen_string_literal: true

require "bundler/setup"
require "rspec/matchers"
require "equivalent-xml"
require "simplecov"
require "yaml"
require "jing"

SimpleCov.start do
  add_filter "/spec/"
end

require "relaton/ietf"

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expose_dsl_globally = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
