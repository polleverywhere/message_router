require 'rubygems'
require 'bundler'
Bundler.setup(:test)

if ENV["COVERAGE"] == "true"
  require 'simplecov'

  SimpleCov.start do
    add_filter '../lib'
    add_filter './'
  end
end

require 'message_router'
require 'rspec'

RSpec.configure do |config|
end