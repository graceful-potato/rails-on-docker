# Install gems
gem "redis", "~> 5", ">= 5.0.5"
gem "sidekiq", "~> 7", ">= 7.0.2"

gem_group :development, :test do
  gem "rspec-rails", "~> 6"
  gem "capybara", "~> 3", ">= 3.38.0"
  gem "selenium-webdriver", "~> 4", ">= 4.7.1"
end

gem_group :test do
  gem "database_cleaner-active_record", "~> 2", ">= 2.0.1"
end

run "bundle install"

# Setup rspec
generate "rspec:install"

append_file ".rspec" do
  "--order rand"
end

# Setup database config and prepare db for rails
run "rm config/database.yml"
create_file "config/database.yml", <<~YML
  default: &default
    adapter: postgresql
    encoding: unicode
    host: <%= ENV.fetch("DATABASE_HOST") %>
    username: <%= ENV.fetch("DATABASE_USER") %>
    password: <%= ENV.fetch("DATABASE_PASSWORD") %>
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

  development:
    <<: *default
    database: app_development

  test:
    <<: *default
    database: app_test

  production:
    <<: *default
    database: app_production
YML

run "bundle exec rails db:create"
run "bundle exec rails db:migrate"

# Setup sidekiq
initializer "sidekiq.rb" do
  <<~RUBY
    Sidekiq.configure_server do |config|
      config.redis = { url: "redis://redis:6379/0" }
    end
    
    Sidekiq.configure_client do |config|
      config.redis = { url: "redis://redis:6379/0" }
    end
  RUBY
end

prepend_file "config/routes.rb" do
  <<~RUBY
    require "sidekiq/web"

  RUBY
end

inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do\n" do <<-RUBY
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(username, ENV.fetch("SIDEKIQ_USER")) &
      ActiveSupport::SecurityUtils.secure_compare(password, ENV.fetch("SIDEKIQ_PASSWORD"))
  end if Rails.env.production?
  mount Sidekiq::Web, at: "/sidekiq"
RUBY
end

inject_into_file "config/application.rb", before: "  end\nend\n" do <<-RUBY
    config.active_job.queue_adapter = :sidekiq
RUBY
end

# Setup Capybara
gsub_file "spec/rails_helper.rb", /# (Dir\[Rails\.root\.join\('spec', 'support', '\*\*', '\*\.rb'\)\]\.sort\.each { |f| require f })/, '\1'

create_file "spec/support/capybara.rb", <<~RUBY
  require "selenium/webdriver"
  require "capybara/rails"
  require "capybara/rspec"

  Capybara.register_driver :remote_selenium_chrome_headless do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless")
    options.add_argument("--window-size=1400,1400")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      url: "http://selenium_chrome:4444/wd/hub",
      options: options
    )
  end

  Capybara.register_driver :remote_selenium_chrome do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--window-size=1400,1400")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      url: "http://selenium_chrome:4444/wd/hub",
      options: options
    )
  end

  Capybara.configure do |config|
    config.default_max_wait_time = 10 # in seconds
    config.default_driver = :remote_selenium_chrome_headless
    config.javascript_driver = :remote_selenium_chrome_headless
    config.server_host = "0.0.0.0"
    config.server_port = 4000
    config.app_host = "http://web:4000"
    config.server = :puma, { Silent: true }
  end
RUBY

# Setup database cleaner
gsub_file "spec/rails_helper.rb", /(config.use_transactional_fixtures) = true/, '\1 = false'

inject_into_file "spec/rails_helper.rb", after: "require 'rspec/rails'\n" do <<~RUBY
  require "database_cleaner/active_record"
RUBY
end

inject_into_file "spec/rails_helper.rb", after: "# config.filter_gems_from_backtrace(\"gem name\")\n" do <<-RUBY
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each, type: :feature) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
RUBY
end
