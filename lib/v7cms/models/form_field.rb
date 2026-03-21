# frozen_string_literal: true

module V7CMS
  class FormField < ActiveRecord::Base
    FIELD_TYPES = %w[text email textarea select checkbox number tel url radio hidden].freeze

    belongs_to :form, class_name: 'V7CMS::Form', optional: false

    validates :field_type, presence: true, inclusion: { in: FIELD_TYPES }
    validates :name, presence: true,
                     uniqueness: { scope: :form_id },
                     format: { with: /\A[a-z0-9_]+\z/, message: 'only allows lowercase letters, numbers, and underscores' }
    validates :label, presence: true, unless: -> { field_type == 'hidden' }
    validates :options, presence: true, if: -> { %w[select radio].include?(field_type) }
    validate :validate_options_json

    before_validation :generate_name

    def parsed_validation_rules
      return {} if validation_rules.blank?

      JSON.parse(validation_rules)
    rescue JSON::ParserError
      {}
    end

    def parsed_options
      return [] if options.blank?

      JSON.parse(options)
    rescue JSON::ParserError
      []
    end

    private

    def generate_name
      return if name.present? || label.blank?

      self.name = label.downcase
                       .gsub(/[^a-z0-9\s]/, '')
                       .gsub(/\s+/, '_')
                       .gsub(/_+/, '_')
                       .strip
                       .gsub(/^_|_$/, '')
    end

    def validate_options_json
      return if options.blank?

      JSON.parse(options)
    rescue JSON::ParserError
      errors.add(:options, 'must be valid JSON')
    end
  end
end
