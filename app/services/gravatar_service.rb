require 'digest/md5'
require 'net/http'
require 'json'

class GravatarService
  GRAVATAR_BASE = 'https://www.gravatar.com'.freeze
  TIMEOUT = 5 # seconds

  def self.fetch_profile(email)
    new(email).fetch
  end

  def initialize(email)
    @email = email.to_s.strip.downcase
    @hash = Digest::MD5.hexdigest(@email)
  end

  def fetch
    response = fetch_json
    return {} unless response

    {
      avatar_url: avatar_url,
      name: extract_name(response)
    }.compact
  end

  private

  def avatar_url
    "#{GRAVATAR_BASE}/avatar/#{@hash}?s=200&d=404"
  end

  def fetch_json
    uri = URI("#{GRAVATAR_BASE}/#{@hash}.json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    response = http.get(uri.path)
    return nil unless response.code == '200'

    JSON.parse(response.body)
  rescue StandardError => e
    Logger.new(STDOUT).warn("Gravatar lookup failed for #{@email}: #{e.message}")
    nil
  end

  def extract_name(response)
    response.dig('entry', 0, 'displayName')
  end
end
