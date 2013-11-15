# Load the Sinatra app
require File.join(File.dirname(__FILE__), '..', 'app.rb')

require 'rspec'
require 'rspec/expectations'
require 'rack/test'

set :environment, :test

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

def app
  VarnishStatus
end