# frozen_string_literal: true

require 'spec_helper'

RSpec.describe V7CMS::FormField, type: :model do
  let(:form) { V7CMS::Form.create!(name: 'Test Form') }

  describe 'validations' do
    it 'requires form' do
      field = described_class.new(field_type: 'text', name: 'test', label: 'Test')
      expect(field).not_to be_valid
      expect(field.errors[:form]).to include('must exist')
    end

    it 'requires field_type' do
      field = described_class.new(form: form, name: 'test', label: 'Test')
      expect(field).not_to be_valid
      expect(field.errors[:field_type]).to include("can't be blank")
    end

    it 'validates field_type inclusion' do
      field = described_class.new(form: form, field_type: 'color', name: 'test', label: 'Test')
      expect(field).not_to be_valid
      expect(field.errors[:field_type]).to include('is not included in the list')
    end

    it 'allows all 9 valid field types' do
      %w[text email textarea select checkbox number tel url radio hidden].each do |type|
        field = described_class.new(form: form, field_type: type, name: "field_#{type}", label: 'Test')
        field.valid?
        expect(field.errors[:field_type]).to be_empty, "Expected #{type} to be valid"
      end
    end

    it 'requires name when label is also blank' do
      field = described_class.new(form: form, field_type: 'text', name: '', label: '')
      expect(field).not_to be_valid
      expect(field.errors[:name]).to include("can't be blank")
    end

    it 'validates name uniqueness scoped to form' do
      described_class.create!(form: form, field_type: 'text', name: 'email', label: 'Email')
      duplicate = described_class.new(form: form, field_type: 'text', name: 'email', label: 'Email 2')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end

    it 'allows same name on different forms' do
      other_form = V7CMS::Form.create!(name: 'Other Form')
      described_class.create!(form: form, field_type: 'text', name: 'email', label: 'Email')
      field = described_class.new(form: other_form, field_type: 'text', name: 'email', label: 'Email')
      field.valid?
      expect(field.errors[:name]).to be_empty
    end

    it 'validates name format (lowercase alphanumeric + underscores)' do
      field = described_class.new(form: form, field_type: 'text', name: 'Invalid Name!', label: 'Test')
      expect(field).not_to be_valid
      expect(field.errors[:name]).to include('only allows lowercase letters, numbers, and underscores')
    end

    it 'requires label for non-hidden fields' do
      field = described_class.new(form: form, field_type: 'text', name: 'test')
      expect(field).not_to be_valid
      expect(field.errors[:label]).to include("can't be blank")
    end

    it 'does not require label for hidden fields' do
      field = described_class.new(form: form, field_type: 'hidden', name: 'source',
                                   validation_rules: '{"value": "homepage"}')
      field.valid?
      expect(field.errors[:label]).to be_empty
    end

    it 'requires options for select fields' do
      field = described_class.new(form: form, field_type: 'select', name: 'choice', label: 'Choice')
      expect(field).not_to be_valid
      expect(field.errors[:options]).to include("can't be blank")
    end

    it 'requires options for radio fields' do
      field = described_class.new(form: form, field_type: 'radio', name: 'choice', label: 'Choice')
      expect(field).not_to be_valid
      expect(field.errors[:options]).to include("can't be blank")
    end

    it 'validates options is valid JSON' do
      field = described_class.new(form: form, field_type: 'select', name: 'choice', label: 'Choice',
                                   options: 'not json')
      expect(field).not_to be_valid
      expect(field.errors[:options]).to include('must be valid JSON')
    end
  end

  describe 'name generation' do
    it 'auto-generates name from label' do
      field = described_class.new(form: form, field_type: 'text', label: 'Full Name')
      field.valid?
      expect(field.name).to eq('full_name')
    end

    it 'handles special characters' do
      field = described_class.new(form: form, field_type: 'text', label: 'Phone #')
      field.valid?
      expect(field.name).to eq('phone')
    end

    it 'does not overwrite manually set name' do
      field = described_class.new(form: form, field_type: 'text', label: 'Full Name', name: 'custom_name')
      field.valid?
      expect(field.name).to eq('custom_name')
    end
  end

  describe '#parsed_validation_rules' do
    it 'returns parsed JSON hash' do
      field = described_class.new(validation_rules: '{"min": 0, "max": 100}')
      expect(field.parsed_validation_rules).to eq({ 'min' => 0, 'max' => 100 })
    end

    it 'returns empty hash when nil' do
      field = described_class.new(validation_rules: nil)
      expect(field.parsed_validation_rules).to eq({})
    end
  end

  describe '#parsed_options' do
    it 'returns parsed JSON array' do
      field = described_class.new(options: '[{"label":"Yes","value":"yes"},{"label":"No","value":"no"}]')
      expect(field.parsed_options).to eq([{ 'label' => 'Yes', 'value' => 'yes' }, { 'label' => 'No', 'value' => 'no' }])
    end

    it 'returns empty array when nil' do
      field = described_class.new(options: nil)
      expect(field.parsed_options).to eq([])
    end
  end
end
