# frozen_string_literal: true

require 'spec_helper'

RSpec.describe V7CMS::FormHelper do
  let(:test_class) { Class.new { extend V7CMS::FormHelper } }

  let(:form) do
    V7CMS::Form.create!(name: 'Contact', slug: 'contact', published: true)
  end

  before do
    form.form_fields.create!(field_type: 'text', name: 'name', label: 'Name', position: 0)
  end

  describe '.render_form' do
    it 'renders a published form by slug' do
      html = test_class.render_form('contact')
      expect(html).to include('data-form-slug="contact"')
      expect(html).to include('name="name"')
    end

    it 'returns empty string for non-existent slug' do
      expect(test_class.render_form('nonexistent')).to eq('')
    end

    it 'returns empty string for unpublished form' do
      form.update!(published: false)
      expect(test_class.render_form('contact')).to eq('')
    end
  end

  describe '.process_form_shortcodes' do
    it 'replaces [form:slug] with rendered form' do
      content = '<p>Contact us below:</p>[form:contact]<p>Thanks!</p>'
      result = test_class.process_form_shortcodes(content)
      expect(result).to include('data-form-slug="contact"')
      expect(result).to include('Contact us below:')
      expect(result).to include('Thanks!')
    end

    it 'replaces multiple shortcodes' do
      other = V7CMS::Form.create!(name: 'Feedback', slug: 'feedback', published: true)
      other.form_fields.create!(field_type: 'textarea', name: 'fb', label: 'Feedback', position: 0)

      content = '[form:contact] and [form:feedback]'
      result = test_class.process_form_shortcodes(content)
      expect(result).to include('data-form-slug="contact"')
      expect(result).to include('data-form-slug="feedback"')
    end

    it 'removes shortcode for non-existent form' do
      content = '<p>Here: [form:missing]</p>'
      result = test_class.process_form_shortcodes(content)
      expect(result).to eq('<p>Here: </p>')
    end

    it 'returns content unchanged when no shortcodes present' do
      content = '<p>No forms here</p>'
      expect(test_class.process_form_shortcodes(content)).to eq(content)
    end

    it 'returns nil unchanged' do
      expect(test_class.process_form_shortcodes(nil)).to be_nil
    end
  end
end
