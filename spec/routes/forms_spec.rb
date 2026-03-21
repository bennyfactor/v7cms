# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'Forms API', type: :request do
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
      published: true
    }.merge(attrs))
  end

  # =========================================================================
  # Form CRUD
  # =========================================================================

  describe 'GET /api/forms' do
    it 'requires authentication' do
      get '/api/forms'
      expect(last_response.status).to eq(401)
    end

    it 'returns all forms' do
      login_as(user)
      create_form(name: 'Contact')
      create_form(name: 'Survey', slug: 'survey')

      get '/api/forms'
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['forms'].length).to eq(2)
    end

    it 'includes fields_count and submissions_count' do
      login_as(user)
      form = create_form
      form.form_fields.create!(field_type: 'text', name: 'full_name', label: 'Name')
      form.form_submissions.create!(data: '{"full_name":"Alice"}')

      get '/api/forms'
      data = JSON.parse(last_response.body)
      f = data['forms'].first
      expect(f['fields_count']).to eq(1)
      expect(f['submissions_count']).to eq(1)
    end
  end

  describe 'POST /api/forms' do
    it 'requires authentication' do
      post '/api/forms', '{}', { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'creates a form with defaults' do
      login_as(user)
      post '/api/forms', { name: 'Feedback' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(201)
      data = JSON.parse(last_response.body)
      expect(data['form']['name']).to eq('Feedback')
      expect(data['form']['slug']).to eq('feedback')
      expect(data['form']['submit_button_text']).to eq('Submit')
      expect(data['form']['success_message']).to eq('Thank you for your submission.')
      expect(data['form']['store_submissions']).to eq(true)
      expect(data['form']['require_recaptcha']).to eq(true)
    end

    it 'creates a form with custom attributes' do
      login_as(user)
      post '/api/forms', {
        name: 'Survey',
        slug: 'my-survey',
        description: 'A quick survey',
        submit_button_text: 'Send',
        success_message: 'Thanks!',
        notification_email: 'admin@example.com',
        store_submissions: false,
        send_notifications: true,
        require_recaptcha: false,
        published: true
      }.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(201)
      data = JSON.parse(last_response.body)
      expect(data['form']['slug']).to eq('my-survey')
      expect(data['form']['description']).to eq('A quick survey')
      expect(data['form']['notification_email']).to eq('admin@example.com')
      expect(data['form']['store_submissions']).to eq(false)
      expect(data['form']['send_notifications']).to eq(true)
      expect(data['form']['published']).to eq(true)
    end

    it 'returns 422 for invalid form' do
      login_as(user)
      post '/api/forms', { name: '' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(422)
      data = JSON.parse(last_response.body)
      expect(data['errors']).to be_an(Array)
      expect(data['errors']).not_to be_empty
    end
  end

  describe 'GET /api/forms/:id' do
    it 'requires authentication' do
      form = create_form
      get "/api/forms/#{form.id}"
      expect(last_response.status).to eq(401)
    end

    it 'returns form with fields' do
      login_as(user)
      form = create_form
      form.form_fields.create!(field_type: 'text', name: 'full_name', label: 'Full Name')
      form.form_fields.create!(field_type: 'email', name: 'email', label: 'Email')

      get "/api/forms/#{form.id}"
      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data['form']['name']).to eq('Contact Form')
      expect(data['form']['fields'].length).to eq(2)
      expect(data['form']['fields'].first['field_type']).to eq('text')
    end

    it 'returns 404 for missing form' do
      login_as(user)
      get '/api/forms/999'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'PUT /api/forms/:id' do
    it 'requires authentication' do
      form = create_form
      put "/api/forms/#{form.id}", { name: 'Updated' }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'updates form attributes' do
      login_as(user)
      form = create_form
      put "/api/forms/#{form.id}", { name: 'Updated Form', published: true }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['form']['name']).to eq('Updated Form')
      expect(data['form']['published']).to eq(true)
    end

    it 'returns 404 for missing form' do
      login_as(user)
      put '/api/forms/999', { name: 'X' }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(404)
    end

    it 'returns 422 for invalid update' do
      login_as(user)
      form = create_form
      put "/api/forms/#{form.id}", { name: '' }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(422)
    end
  end

  describe 'DELETE /api/forms/:id' do
    it 'requires authentication' do
      form = create_form
      delete "/api/forms/#{form.id}", '', { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'deletes a form' do
      login_as(user)
      form = create_form
      delete "/api/forms/#{form.id}", '', { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['success']).to eq(true)
      expect(V7CMS::Form.find_by(id: form.id)).to be_nil
    end

    it 'returns 404 for missing form' do
      login_as(user)
      delete '/api/forms/999', '', { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(404)
    end
  end

  # =========================================================================
  # Form Field CRUD
  # =========================================================================

  describe 'POST /api/forms/:id/fields' do
    it 'requires authentication' do
      form = create_form
      post "/api/forms/#{form.id}/fields", { field_type: 'text', label: 'Name' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(401)
    end

    it 'creates a text field' do
      login_as(user)
      form = create_form
      post "/api/forms/#{form.id}/fields", {
        field_type: 'text',
        label: 'Full Name',
        placeholder: 'Enter your name',
        required: true
      }.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(201)
      data = JSON.parse(last_response.body)
      expect(data['field']['field_type']).to eq('text')
      expect(data['field']['name']).to eq('full_name')
      expect(data['field']['label']).to eq('Full Name')
      expect(data['field']['required']).to eq(true)
    end

    it 'creates a select field with options' do
      login_as(user)
      form = create_form
      post "/api/forms/#{form.id}/fields", {
        field_type: 'select',
        label: 'Category',
        options: [{ label: 'Bug', value: 'bug' }, { label: 'Feature', value: 'feature' }]
      }.to_json, { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response.status).to eq(201)
      data = JSON.parse(last_response.body)
      expect(data['field']['field_type']).to eq('select')
      options = JSON.parse(data['field']['options'])
      expect(options.length).to eq(2)
    end

    it 'returns 422 for invalid field' do
      login_as(user)
      form = create_form
      post "/api/forms/#{form.id}/fields", { field_type: 'invalid' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(422)
    end

    it 'returns 404 for missing form' do
      login_as(user)
      post '/api/forms/999/fields', { field_type: 'text', label: 'X' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(404)
    end
  end

  describe 'PUT /api/form-fields/:id' do
    it 'updates a field' do
      login_as(user)
      form = create_form
      field = form.form_fields.create!(field_type: 'text', name: 'email', label: 'Email')

      put "/api/form-fields/#{field.id}", { label: 'Email Address', required: true }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data['field']['label']).to eq('Email Address')
      expect(data['field']['required']).to eq(true)
    end

    it 'returns 404 for missing field' do
      login_as(user)
      put '/api/form-fields/999', { label: 'X' }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(404)
    end
  end

  describe 'DELETE /api/form-fields/:id' do
    it 'deletes a field' do
      login_as(user)
      form = create_form
      field = form.form_fields.create!(field_type: 'text', name: 'email', label: 'Email')

      delete "/api/form-fields/#{field.id}", '', { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok
      expect(V7CMS::FormField.find_by(id: field.id)).to be_nil
    end

    it 'returns 404 for missing field' do
      login_as(user)
      delete '/api/form-fields/999', '', { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(404)
    end
  end

  describe 'PUT /api/forms/:id/reorder-fields' do
    it 'reorders fields' do
      login_as(user)
      form = create_form
      f1 = form.form_fields.create!(field_type: 'text', name: 'first', label: 'First', position: 0)
      f2 = form.form_fields.create!(field_type: 'text', name: 'second', label: 'Second', position: 1)
      f3 = form.form_fields.create!(field_type: 'text', name: 'third', label: 'Third', position: 2)

      put "/api/forms/#{form.id}/reorder-fields", { field_ids: [f3.id, f1.id, f2.id] }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(last_response).to be_ok

      expect(f3.reload.position).to eq(0)
      expect(f1.reload.position).to eq(1)
      expect(f2.reload.position).to eq(2)
    end

    it 'returns 404 for missing form' do
      login_as(user)
      put '/api/forms/999/reorder-fields', { field_ids: [] }.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(404)
    end
  end
end
