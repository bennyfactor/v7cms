require 'spec_helper'
require 'cgi'

# Drives the real OmniAuth strategies (test mode off) to prove the OAuth
# state parameter is issued on the request phase and enforced on callback,
# and that the request phase itself only starts from a POST carrying the
# session's authenticity token.
RSpec.describe 'OAuth state (CSRF) protection' do
  around do |example|
    original_admins = ENV.fetch('ADMIN_EMAILS', nil)
    ENV['ADMIN_EMAILS'] = 'test@example.com'
    OmniAuth.config.test_mode = false
    example.run
  ensure
    OmniAuth.config.test_mode = true
    ENV['ADMIN_EMAILS'] = original_admins
  end

  def csrf_token
    get '/api/auth/csrf'
    expect(last_response).to be_ok
    JSON.parse(last_response.body)['token']
  end

  def start_and_capture_state(provider)
    post "/auth/#{provider}", authenticity_token: csrf_token
    expect(last_response.status).to eq(302)
    CGI.parse(URI(last_response.headers['Location']).query)['state'].first
  end

  # Google verifies the id_token's issuer, audience, and expiry claims (unsigned
  # decode), so the stub must return a well-formed token for the configured client.
  def google_id_token
    payload = { iss: 'accounts.google.com', aud: ENV.fetch('GOOGLE_CLIENT_ID'), sub: '123',
                email: 'test@example.com', email_verified: true, exp: Time.now.to_i + 3600, iat: Time.now.to_i }
    JWT.encode(payload, nil, 'none')
  end

  def stub_provider(provider)
    case provider
    when 'google_oauth2'
      stub_request(:post, 'https://oauth2.googleapis.com/token')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                   body: { access_token: 'tok', token_type: 'Bearer', expires_in: 3600, id_token: google_id_token }.to_json)
      stub_request(:post, 'https://www.googleapis.com/oauth2/v3/tokeninfo')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                   body: { sub: '123', email: 'test@example.com', email_verified: 'true', aud: 'client' }.to_json)
      stub_request(:get, 'https://www.googleapis.com/oauth2/v3/userinfo')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                   body: { sub: '123', email: 'test@example.com', email_verified: true, name: 'Test' }.to_json)
    when 'github'
      stub_request(:post, 'https://github.com/login/oauth/access_token')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                   body: { access_token: 'tok', token_type: 'bearer' }.to_json)
      stub_request(:get, 'https://api.github.com/user')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                   body: { id: 123, login: 'tester', name: 'Test', email: 'test@example.com' }.to_json)
      stub_request(:get, 'https://api.github.com/user/emails')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                   body: [{ email: 'test@example.com', primary: true, verified: true }].to_json)
    end
  end

  describe 'GET /api/auth/csrf' do
    it 'returns an authenticity token for the login forms' do
      get '/api/auth/csrf'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
      token = JSON.parse(last_response.body)['token']
      expect(token).to be_a(String)
      expect(token).not_to be_empty
    end
  end

  %w[google_oauth2 github].each do |provider|
    describe provider do
      it 'issues a state parameter on the request phase' do
        expect(start_and_capture_state(provider)).to match(/\A[0-9a-f]{48}\z/)
      end

      it 'rejects a POST without an authenticity token' do
        post "/auth/#{provider}"

        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to include('message=authenticity_error')
      end

      it 'does not start the flow from a GET request' do
        get "/auth/#{provider}"

        expect(last_response.status).to eq(404)
      end

      it 'rejects a callback whose state does not match the session' do
        start_and_capture_state(provider)
        get "/auth/#{provider}/callback?code=abc&state=forged"
        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to include('/auth/failure?message=csrf_detected')
      end

      it 'rejects a callback with no state at all' do
        start_and_capture_state(provider)
        get "/auth/#{provider}/callback?code=abc"
        expect(last_response.headers['Location']).to include('message=csrf_detected')
      end

      it 'completes the login when the state matches' do
        stub_provider(provider)
        state = start_and_capture_state(provider)
        get "/auth/#{provider}/callback?code=abc&state=#{state}"
        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to end_with('/admin/')
        expect(User.find_by(email: 'test@example.com')).to be_admin
      end
    end
  end
end
