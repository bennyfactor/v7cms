require 'rack/attack'
require 'active_support/cache'
require 'active_support/core_ext/numeric/time'

# Use FileStore for FastCGI multi-process support
# All FastCGI processes share the same cache files in ./tmp
cache_dir = File.join(File.expand_path('..', __dir__), 'tmp', 'rack-attack-cache')
Rack::Attack.cache.store = ActiveSupport::Cache::FileStore.new(
  cache_dir,
  expires_in: 1.hour
)

# Allow 100 requests per minute per IP for general traffic
# Excludes /admin paths (static files, no need to rate limit)
Rack::Attack.throttle('req/ip', limit: 100, period: 60) do |req|
  req.ip unless req.path.start_with?('/admin')
end

# Allow 20 requests per minute per IP for API writes
# Protects POST, PUT, DELETE endpoints from abuse
Rack::Attack.throttle('api/writes/ip', limit: 20, period: 60) do |req|
  if req.path.start_with?('/api/') && ['POST', 'PUT', 'DELETE'].include?(req.env['REQUEST_METHOD'])
    req.ip
  end
end

# Allow 5 login attempts per minute per IP
# Prevents brute force attacks on OAuth endpoints
Rack::Attack.throttle('logins/ip', limit: 5, period: 60) do |req|
  if req.path.start_with?('/auth/') && req.post?
    req.ip
  end
end

# Block requests from known bad IPs (optional)
# Configure via BLOCKED_IPS environment variable (comma-separated)
Rack::Attack.blocklist('block bad IPs') do |req|
  bad_ips = ENV['BLOCKED_IPS']&.split(',') || []
  bad_ips.include?(req.ip)
end

# Custom response for rate limited requests
# Returns 429 with Retry-After header
Rack::Attack.throttled_responder = lambda do |req|
  retry_after = req.env['rack.attack.match_data'][:period]

  [
    429,
    {
      'Content-Type' => 'application/json',
      'Retry-After' => retry_after.to_s
    },
    [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]
  ]
end
