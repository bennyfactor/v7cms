require_relative 'app/cms'
require 'rack/test'

include Rack::Test::Methods

def app
  Sinatra::Application
end

# Test feed route
response = get '/feed.xml'
puts "Status: #{response.status}"
puts "Content-Type: #{response.headers['Content-Type']}"
puts "Body preview: #{response.body[0..200]}"
