require 'spec_helper'

RSpec.describe 'Session cookie attributes' do
  it 'marks the session cookie HttpOnly and SameSite=Lax' do
    get '/api/auth/me'
    cookie = last_response.headers['Set-Cookie']
    expect(cookie).to include('rack.session=')
    expect(cookie).to match(/httponly/i)
    expect(cookie).to match(/samesite=lax/i)
  end

  it 'does not require Secure outside production so local HTTP development works' do
    get '/api/auth/me'
    expect(last_response.headers['Set-Cookie']).not_to match(/;\s*secure/i)
  end
end
