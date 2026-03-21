# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'Form Submissions API', type: :request do
  let(:user) { V7CMS::User.create!(email: 'test@example.com', name: 'Test', provider: 'google_oauth2', uid: '12345', admin: true) }

  def app
    CMS
  end

  def login_as(user)
    env 'rack.session', { user_id: user.id }
  end

  def create_form(attrs = {})
    V7CMS::Form.create!({
      name: 'Contact Form',
      submit_button_text: 'Submit',
      success_message: 'Thank you!',
      published: true,
      store_submissions: true,
      require_recaptcha: false
    }.merge(attrs))
  end

  def create_form_with_fields
    form = create_form
    form.form_fields.create!(field_type: 'text', name: 'full_name', label: 'Full Name', required: true, position: 0)
    form.form_fields.create!(field_type: 'email', name: 'email', label: 'Email', required: true, position: 1)
    form.form_fields.create!(field_type: 'textarea', name: 'message', label: 'Message', position: 2)
    form
  end

  # =========================================================================
  # Submission Management (Admin)
  # =========================================================================

  describe 'GET /api/forms/:id/submissions' do
    it 'requires authentication' do
      form = create_form
      get "/api/forms/#{form.id}/submissions"
      expect(last_response.status).to eq(401)
    end

    it 'returns paginated submissions' do
      login_as(user)
      form = create_form
      3.times { |i| form.form_submissions.create!(data: { name: "User #{i}" }.to_json) }

      get "/api/forms/#{form.id}/submissions"
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['submissions'].length).to eq(3)
      expect(data['total']).to eq(3)
      expect(data['page']).to eq(1)
    end

    it 'supports pagination params' do
      login_as(user)
      form = create_form
      5.times { |i| form.form_submissions.create!(data: { name: "User #{i}" }.to_json) }

      get "/api/forms/#{form.id}/submissions?page=2&per_page=2"
      data = JSON.parse(last_response.body)
      expect(data['submissions'].length).to eq(2)
      expect(data['page']).to eq(2)
      expect(data['total']).to eq(5)
    end

    it 'filters by not_spam' do
      login_as(user)
      form = create_form
      form.form_submissions.create!(data: '{"a":"1"}', spam: false)
      form.form_submissions.create!(data: '{"a":"2"}', spam: true)

      get "/api/forms/#{form.id}/submissions?filter=not_spam"
      data = JSON.parse(last_response.body)
      expect(data['submissions'].length).to eq(1)
      expect(data['total']).to eq(1)
    end

    it 'filters by spam' do
      login_as(user)
      form = create_form
      form.form_submissions.create!(data: '{"a":"1"}', spam: false)
      form.form_submissions.create!(data: '{"a":"2"}', spam: true)

      get "/api/forms/#{form.id}/submissions?filter=spam"
      data = JSON.parse(last_response.body)
      expect(data['submissions'].length).to eq(1)
      expect(data['submissions'].first['spam']).to eq(true)
    end

    it 'returns 404 for missing form' do
      login_as(user)
      get '/api/forms/999/submissions'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'GET /api/forms/:id/submissions/:submission_id' do
    it 'returns a single submission' do
      login_as(user)
      form = create_form
      sub = form.form_submissions.create!(data: '{"name":"Alice"}')

      get "/api/forms/#{form.id}/submissions/#{sub.id}"
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['submission']['data']['name']).to eq('Alice')
    end

    it 'returns 404 for missing submission' do
      login_as(user)
      form = create_form
      get "/api/forms/#{form.id}/submissions/999"
      expect(last_response.status).to eq(404)
    end

    it 'returns 404 for missing form' do
      login_as(user)
      get '/api/forms/999/submissions/1'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'DELETE /api/forms/:id/submissions/:submission_id' do
    it 'requires authentication' do
      form = create_form
      sub = form.form_submissions.create!(data: '{"a":"1"}')
      delete "/api/forms/#{form.id}/submissions/#{sub.id}", '', { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'deletes a submission' do
      login_as(user)
      form = create_form
      sub = form.form_submissions.create!(data: '{"a":"1"}')

      delete "/api/forms/#{form.id}/submissions/#{sub.id}", '', { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['success']).to eq(true)
      expect(V7CMS::FormSubmission.find_by(id: sub.id)).to be_nil
    end

    it 'returns 404 for missing submission' do
      login_as(user)
      form = create_form
      delete "/api/forms/#{form.id}/submissions/999", '', { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(404)
    end
  end

  # =========================================================================
  # CSV Export
  # =========================================================================

  describe 'GET /api/forms/:id/submissions/export' do
    it 'requires authentication' do
      form = create_form
      get "/api/forms/#{form.id}/submissions/export"
      expect(last_response.status).to eq(401)
    end

    it 'exports submissions as CSV' do
      login_as(user)
      form = create_form_with_fields
      form.form_submissions.create!(data: { full_name: 'Alice', email: 'alice@example.com', message: 'Hello' }.to_json, ip_address: '127.0.0.1')
      form.form_submissions.create!(data: { full_name: 'Bob', email: 'bob@example.com', message: 'Hi' }.to_json, ip_address: '127.0.0.2')

      get "/api/forms/#{form.id}/submissions/export"
      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to include('text/csv')

      require 'csv'
      rows = CSV.parse(last_response.body)
      expect(rows.first).to include('Full Name', 'Email', 'Message', 'IP Address', 'Spam')
      expect(rows.length).to eq(3) # header + 2 submissions
    end

    it 'returns 404 for missing form' do
      login_as(user)
      get '/api/forms/999/submissions/export'
      expect(last_response.status).to eq(404)
    end
  end

  # =========================================================================
  # Public Form Routes
  # =========================================================================

  describe 'GET /forms/:slug' do
    it 'renders a published form' do
      form = create_form_with_fields
      get "/forms/#{form.slug}"

      expect(last_response).to be_ok
      expect(last_response.body).to include('Contact Form')
      expect(last_response.body).to include('Full Name')
    end

    it 'returns 404 for unpublished form' do
      form = create_form(published: false)
      get "/forms/#{form.slug}"
      expect(last_response.status).to eq(404)
    end

    it 'returns 404 for missing form' do
      get '/forms/nonexistent'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /forms/:slug/submit' do
    it 'accepts valid submission' do
      form = create_form_with_fields

      post "/forms/#{form.slug}/submit",
           { full_name: 'Alice', email: 'alice@example.com', message: 'Hello' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['success']).to eq(true)
      expect(data['message']).to eq('Thank you!')

      expect(form.form_submissions.count).to eq(1)
    end

    it 'rejects submission with missing required fields' do
      form = create_form_with_fields

      post "/forms/#{form.slug}/submit",
           { full_name: '', email: '', message: 'Hello' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(422)
      data = JSON.parse(last_response.body)
      expect(data['errors']).to include('Full Name is required')
      expect(data['errors']).to include('Email is required')
    end

    it 'rejects submission with invalid email' do
      form = create_form_with_fields

      post "/forms/#{form.slug}/submit",
           { full_name: 'Alice', email: 'not-an-email', message: 'Hello' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(422)
      data = JSON.parse(last_response.body)
      expect(data['errors']).to include('Email must be a valid email address')
    end

    it 'returns 404 for unpublished form' do
      form = create_form(published: false)
      post "/forms/#{form.slug}/submit",
           { name: 'test' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(404)
    end

    it 'returns 404 for missing form' do
      post '/forms/nonexistent/submit',
           { name: 'test' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(404)
    end

    it 'returns 422 for invalid JSON' do
      form = create_form_with_fields
      post "/forms/#{form.slug}/submit", 'not json', { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(422)
    end

    it 'does not store submission when store_submissions is false' do
      form = create_form_with_fields
      form.update!(store_submissions: false)

      post "/forms/#{form.slug}/submit",
           { full_name: 'Alice', email: 'alice@example.com' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      expect(form.form_submissions.count).to eq(0)
    end

    it 'sends notification email for valid submission' do
      form = create_form_with_fields
      form.update!(send_notifications: true, notification_email: 'admin@example.com')

      expect(V7CMS::FormMailer).to receive(:send_notification).with(form, anything, anything)

      post "/forms/#{form.slug}/submit",
           { full_name: 'Alice', email: 'alice@example.com' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
    end
  end
end
