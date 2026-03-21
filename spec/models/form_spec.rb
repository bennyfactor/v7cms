# frozen_string_literal: true

require 'spec_helper'

RSpec.describe V7CMS::Form, type: :model do
  describe 'validations' do
    it 'requires name' do
      form = described_class.new(submit_button_text: 'Send', success_message: 'Thanks')
      expect(form).not_to be_valid
      expect(form.errors[:name]).to include("can't be blank")
    end

    it 'requires name max 255 characters' do
      form = described_class.new(name: 'a' * 256, submit_button_text: 'Send', success_message: 'Thanks')
      expect(form).not_to be_valid
      expect(form.errors[:name]).to include('is too long (maximum is 255 characters)')
    end

    it 'requires submit_button_text' do
      form = described_class.new(name: 'Test', submit_button_text: '', success_message: 'Thanks')
      expect(form).not_to be_valid
      expect(form.errors[:submit_button_text]).to include("can't be blank")
    end

    it 'requires success_message' do
      form = described_class.new(name: 'Test', submit_button_text: 'Send', success_message: '')
      expect(form).not_to be_valid
      expect(form.errors[:success_message]).to include("can't be blank")
    end

    it 'validates notification_email format when present' do
      form = described_class.new(name: 'Test', notification_email: 'not-an-email')
      expect(form).not_to be_valid
      expect(form.errors[:notification_email]).to include('is invalid')
    end

    it 'allows blank notification_email' do
      form = described_class.new(name: 'Test', notification_email: '')
      form.valid?
      expect(form.errors[:notification_email]).to be_empty
    end

    it 'validates recaptcha_threshold range' do
      form = described_class.new(name: 'Test', recaptcha_threshold: 1.5)
      expect(form).not_to be_valid
      expect(form.errors[:recaptcha_threshold]).to include('must be less than or equal to 1.0')
    end

    it 'validates spam_behavior inclusion' do
      form = described_class.new(name: 'Test', spam_behavior: 'ignore')
      expect(form).not_to be_valid
      expect(form.errors[:spam_behavior]).to include('is not included in the list')
    end

    it 'validates slug uniqueness' do
      described_class.create!(name: 'Contact Form')
      duplicate = described_class.new(name: 'Contact Form')
      duplicate.valid?
      expect(duplicate.errors[:slug]).to include('has already been taken')
    end

    it 'validates slug format' do
      form = described_class.new(name: 'Test', slug: 'INVALID SLUG!')
      expect(form).not_to be_valid
      expect(form.errors[:slug]).to include('only allows lowercase letters, numbers, and hyphens')
    end
  end

  describe 'slug generation' do
    it 'auto-generates slug from name' do
      form = described_class.new(name: 'Contact Us Form')
      form.valid?
      expect(form.slug).to eq('contact-us-form')
    end

    it 'handles special characters in name' do
      form = described_class.new(name: "Ben's Inquiry Form!")
      form.valid?
      expect(form.slug).to eq('bens-inquiry-form')
    end

    it 'does not overwrite manually set slug' do
      form = described_class.new(name: 'Contact', slug: 'custom-slug')
      form.valid?
      expect(form.slug).to eq('custom-slug')
    end
  end

  describe 'associations' do
    it 'has many form_fields ordered by position' do
      form = described_class.create!(name: 'Test Form')
      field2 = form.form_fields.create!(field_type: 'text', name: 'last', label: 'Last', position: 2)
      field1 = form.form_fields.create!(field_type: 'text', name: 'first', label: 'First', position: 1)
      expect(form.form_fields.reload).to eq([field1, field2])
    end

    it 'destroys form_fields on delete' do
      form = described_class.create!(name: 'Test Form')
      form.form_fields.create!(field_type: 'text', name: 'field1', label: 'Field 1')
      expect { form.destroy }.to change(V7CMS::FormField, :count).by(-1)
    end

    it 'destroys form_submissions on delete' do
      form = described_class.create!(name: 'Test Form')
      V7CMS::FormSubmission.create!(form: form, data: '{"test":"value"}')
      expect { form.destroy }.to change(V7CMS::FormSubmission, :count).by(-1)
    end
  end

  describe 'scopes' do
    it '.published returns only published forms' do
      published = described_class.create!(name: 'Published', published: true)
      described_class.create!(name: 'Draft', published: false)
      expect(described_class.published).to eq([published])
    end
  end

  describe '#validate_submission' do
    let(:form) { described_class.create!(name: 'Test Form') }

    before do
      form.form_fields.create!(field_type: 'text', name: 'full_name', label: 'Full Name', required: true, position: 0)
      form.form_fields.create!(field_type: 'email', name: 'email', label: 'Email', required: true, position: 1)
      form.form_fields.create!(field_type: 'number', name: 'age', label: 'Age', required: false, position: 2,
                                validation_rules: '{"min": 0, "max": 150}')
      form.form_fields.create!(field_type: 'textarea', name: 'message', label: 'Message', required: false, position: 3)
    end

    it 'returns empty array for valid data' do
      errors = form.validate_submission({ 'full_name' => 'John', 'email' => 'john@example.com' })
      expect(errors).to be_empty
    end

    it 'returns errors for missing required fields' do
      errors = form.validate_submission({ 'email' => 'john@example.com' })
      expect(errors).to include('Full Name is required')
    end

    it 'returns errors for blank required fields' do
      errors = form.validate_submission({ 'full_name' => '', 'email' => 'john@example.com' })
      expect(errors).to include('Full Name is required')
    end

    it 'validates email format' do
      errors = form.validate_submission({ 'full_name' => 'John', 'email' => 'not-an-email' })
      expect(errors).to include('Email must be a valid email address')
    end

    it 'validates number min/max' do
      errors = form.validate_submission({ 'full_name' => 'John', 'email' => 'j@e.com', 'age' => '200' })
      expect(errors).to include('Age must be at most 150')
    end

    it 'allows valid number within range' do
      errors = form.validate_submission({ 'full_name' => 'John', 'email' => 'j@e.com', 'age' => '25' })
      expect(errors).to be_empty
    end

    it 'ignores non-existent fields in data' do
      errors = form.validate_submission({ 'full_name' => 'John', 'email' => 'j@e.com', 'unknown' => 'value' })
      expect(errors).to be_empty
    end
  end
end
