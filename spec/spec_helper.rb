$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'message_router'
require 'rubygems'
require 'bundler'
Bundler.setup(:test)

require 'rspec'

RSpec.configure do |config|
end