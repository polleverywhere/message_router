source "https://rubygems.org"

# Specify your gem's dependencies in message_router.gemspec
gemspec

group :ci, :test, :development do
  gem 'rspec'
  gem 'rake'
end

group :test, :development do
  gem 'listen'
  gem 'growl'
  gem 'guard'
  gem 'guard-rspec'
  gem 'simplecov', require: false
end
