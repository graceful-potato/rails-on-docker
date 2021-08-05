# Development container for Rails

These containers are for rails app with postgresql, rspec, capybara, sidekiq and redis.

## Features

Separate containers for:

* Rails app
* Postgresql
* Redis
* Sidekiq
* Selenium Chrome for capybara

You can change `ruby`, `node`, `yarn` and `bundler` versions in `.env` file. Also you will find default password for postgres and sidekiq web ui in this file.

It persists history of commands for `bash`, `irb`, `pry`, `psql` and `redis-cli`. You can copy your existing history files in the `.dockerdev` directory if you want use your history in containers.

For Linux users:
The user inside rails app container is created dynamically. He will be assigned the same uid (user id) and gid (group id) as your host user so you dont have to `chown` generated files.

## Creating new Rails App

Available options for -j are `esbuild`, `webpack`, `rollup`
Available options for -c are  `tailwind`, `bootstrap`, `bulma`, `postcss`, `sass`

**IMPORTANT**
It will not work out of the box with `importmap`

* Clone repo
* `cd` into directory
* Run the container `docker-compose run --rm web bash`
* Run in the container `gem install rails` you can specify version with `-v` option
* Run in the container `rails new . -T -d postgresql -j esbuild -c postcss -m template.rb -f`
* Exit container when it finish
* `docker-compose up` to run application

## Dockerizing an existing Rails App

**IMPORTANT**
It will not work out of the box if your app using `importmap`

1. Copy files from this repository into your rails app directory except `README.md`

2. Make sure that you have these gems in your Gemfile:

```ruby
gem "redis", "~> 5", ">= 5.0.5"
gem "sidekiq", "~> 7", ">= 7.0.2"

group :development, :test do
  gem "rspec-rails", "~> 6"
  gem "capybara", "~> 3", ">= 3.38.0"
  gem "selenium-webdriver", "~> 4", ">= 4.7.1"
end

group :test do
  gem "database_cleaner-active_record", "~> 2", ">= 2.0.1"
end
```

3. Change database.yml to this:

```yaml
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
```

4. Create `sidekiq.rb` file in `config/initializer/` with this code:

```ruby
Sidekiq.configure_server do |config|
  config.redis = { url: "redis://redis:6379/0" }
end

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://redis:6379/0" }
end
```

5. Find and uncomment `Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }` line in `rails_helper.rb`

6. Create file `capybara.rb` in `spec/support` with this code:

```ruby
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
```

7. In `rails_helper.rb` after line `require 'rspec/rails'` insert `require "database_cleaner/active_record"`

8. In `rails_helper.rb` find and set `config.use_transactional_fixtures` to `false`

9. In `rails_helper.rb` insert this code in `RSpec.configure do |config|` block:

```ruby
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
```

10. Run the container `docker-compose run --rm web bash`

11. Run in the container `yarn install`

12. Run in the container `bundle install`

13. Run in the container `bundle exec rails db:create`

14. Run in the container `bundle exec rails db:migrate`

15. Exit container when it finish

16. `docker-compose up` to run application

## How to start application

`docker-compose up`

or you can start it in background

`docker-compose up -d`

## How to run rails console

`docker-compose run --rm web rails c`

or if your app is already running

`docker-compoae exec web rails c`

## How to use rails generators

`docker-compose run --rm web rails generate model Post title:string body:text`

or if your app is already running

`docker-compose exec web rails generate model Post title:string body:text`

## How to run rspec tests

`docker-compose run --rm web rspec`

or if your app is already running

`docker-compose exec web rspec`

## How to debug

Since `docker-compose up` can't redirect user input to container with running debugger there are 2 solutions. Either you can stop web container and start it manualy using `run` command or attach to your running web container.

Lets say that we already have our rails app up and running in the background.

Solution 1:

```sh
docker-compose stop web
docker-compose run --service-ports web
```

Solution 2:

```sh
docker attach your_container_name
# container name usually constructs from current directory name, service name (web) and number.
# so if you are in rails-app directory then your container name will be rails-app-web-1
```

After that navigate to the page in your browser that will hit breakpoint in your code.

## How to run psql

You can run `psql` either from web container or from database container.
From web container:

* `docker-compose run --rm web psql -U postgres -h database`
or if your app is already running
`docker-compose exec web psql -U postgres -h database`

From database container:

* Your database container should be up and running
`docker-compose exec database psql -U postgres`

## How to run redis-cli

Your redis container should be up and running
`docker-compose exec redis redis-cli`
