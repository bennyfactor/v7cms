# frozen_string_literal: true

require 'spec_helper'

RSpec.describe V7CMS::FormRenderer do
  let(:form) do
    V7CMS::Form.create!(
      name: 'Contact',
      slug: 'contact',
      submit_button_text: 'Send Message',
      require_recaptcha: true,
      published: true
    )
  end

  before do
    form.form_fields.create!(field_type: 'text', name: 'full_name', label: 'Full Name',
                             placeholder: 'John Doe', required: true, position: 0)
    form.form_fields.create!(field_type: 'email', name: 'email', label: 'Email',
                             required: true, help_text: 'We will not share your email', position: 1)
    form.form_fields.create!(field_type: 'textarea', name: 'message', label: 'Message',
                             placeholder: 'Your message...', required: false, position: 2)
  end

  describe '.render' do
    let(:html) { described_class.render(form) }

    it 'generates a form tag with correct action' do
      expect(html).to include('action="/forms/contact/submit"')
      expect(html).to include('method="POST"')
    end

    it 'includes data-form-slug attribute' do
      expect(html).to include('data-form-slug="contact"')
    end

    it 'renders text input with attributes' do
      expect(html).to include('type="text"')
      expect(html).to include('name="full_name"')
      expect(html).to include('placeholder="John Doe"')
      expect(html).to include('required')
    end

    it 'renders email input' do
      expect(html).to include('type="email"')
      expect(html).to include('name="email"')
    end

    it 'renders textarea' do
      expect(html).to include('<textarea')
      expect(html).to include('name="message"')
      expect(html).to include('placeholder="Your message..."')
    end

    it 'renders labels' do
      expect(html).to include('<label')
      expect(html).to include('Full Name')
    end

    it 'renders help text' do
      expect(html).to include('We will not share your email')
    end

    it 'renders submit button with custom text' do
      expect(html).to include('Send Message')
      expect(html).to include('type="submit"')
    end

    it 'includes recaptcha data attribute when enabled' do
      expect(html).to include('data-recaptcha="true"')
    end

    it 'does not include recaptcha attribute when disabled' do
      form.update!(require_recaptcha: false)
      html = described_class.render(form)
      expect(html).not_to include('data-recaptcha="true"')
    end
  end

  describe 'field types' do
    it 'renders select with options' do
      form.form_fields.create!(field_type: 'select', name: 'topic', label: 'Topic', position: 3,
                               options: '[{"label":"Sales","value":"sales"},{"label":"Support","value":"support"}]')
      html = described_class.render(form)
      expect(html).to include('<select')
      expect(html).to include('<option value="sales">Sales</option>')
      expect(html).to include('<option value="support">Support</option>')
    end

    it 'renders radio buttons' do
      form.form_fields.create!(field_type: 'radio', name: 'priority', label: 'Priority', position: 3,
                               options: '[{"label":"Low","value":"low"},{"label":"High","value":"high"}]')
      html = described_class.render(form)
      expect(html).to include('type="radio"')
      expect(html).to include('value="low"')
      expect(html).to include('value="high"')
    end

    it 'renders checkbox' do
      form.form_fields.create!(field_type: 'checkbox', name: 'agree', label: 'I agree to terms', position: 3)
      html = described_class.render(form)
      expect(html).to include('type="checkbox"')
      expect(html).to include('name="agree"')
    end

    it 'renders number input with min/max' do
      form.form_fields.create!(field_type: 'number', name: 'quantity', label: 'Quantity', position: 3,
                               validation_rules: '{"min": 1, "max": 10}')
      html = described_class.render(form)
      expect(html).to include('type="number"')
      expect(html).to include('min="1"')
      expect(html).to include('max="10"')
    end

    it 'renders tel input' do
      form.form_fields.create!(field_type: 'tel', name: 'phone', label: 'Phone', position: 3)
      html = described_class.render(form)
      expect(html).to include('type="tel"')
    end

    it 'renders url input' do
      form.form_fields.create!(field_type: 'url', name: 'website', label: 'Website', position: 3)
      html = described_class.render(form)
      expect(html).to include('type="url"')
    end

    it 'renders hidden input with value' do
      form.form_fields.create!(field_type: 'hidden', name: 'source', position: 3,
                               validation_rules: '{"value": "homepage"}')
      html = described_class.render(form)
      expect(html).to include('type="hidden"')
      expect(html).to include('name="source"')
      expect(html).to include('value="homepage"')
    end
  end

  describe 'validation attributes' do
    it 'adds minlength and maxlength' do
      form.form_fields.create!(field_type: 'text', name: 'code', label: 'Code', position: 3,
                               validation_rules: '{"min_length": 3, "max_length": 10}')
      html = described_class.render(form)
      expect(html).to include('minlength="3"')
      expect(html).to include('maxlength="10"')
    end

    it 'adds pattern attribute' do
      form.form_fields.create!(field_type: 'text', name: 'zip', label: 'ZIP Code', position: 3,
                               validation_rules: '{"pattern": "\\\\d{5}"}')
      html = described_class.render(form)
      expect(html).to include('pattern=')
    end
  end
end
