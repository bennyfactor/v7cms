# frozen_string_literal: true

require 'spec_helper'

RSpec.describe V7CMS::FormSubmission, type: :model do
  let(:form) { V7CMS::Form.create!(name: 'Test Form') }

  describe 'validations' do
    it 'requires form' do
      submission = described_class.new(data: '{"test":"value"}')
      expect(submission).not_to be_valid
      expect(submission.errors[:form]).to include('must exist')
    end

    it 'requires data' do
      submission = described_class.new(form: form)
      expect(submission).not_to be_valid
      expect(submission.errors[:data]).to include("can't be blank")
    end

    it 'creates valid submission' do
      submission = described_class.new(form: form, data: '{"name":"John"}', ip_address: '1.2.3.4', recaptcha_score: 0.9)
      expect(submission).to be_valid
    end
  end

  describe '#parsed_data' do
    it 'returns parsed JSON hash' do
      submission = described_class.new(data: '{"name":"John","email":"j@e.com"}')
      expect(submission.parsed_data).to eq({ 'name' => 'John', 'email' => 'j@e.com' })
    end

    it 'returns empty hash for invalid JSON' do
      submission = described_class.new(data: 'invalid')
      expect(submission.parsed_data).to eq({})
    end
  end

  describe 'scopes' do
    before do
      described_class.create!(form: form, data: '{"t":"1"}', spam: false)
      described_class.create!(form: form, data: '{"t":"2"}', spam: true)
    end

    it '.not_spam returns non-spam submissions' do
      expect(described_class.not_spam.count).to eq(1)
    end

    it '.spam returns spam submissions' do
      expect(described_class.spam.count).to eq(1)
    end
  end
end
