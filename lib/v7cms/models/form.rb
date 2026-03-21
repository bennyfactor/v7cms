# frozen_string_literal: true

module V7CMS
  class Form < ActiveRecord::Base
    has_many :form_fields, -> { order(:position) }, class_name: 'V7CMS::FormField', dependent: :destroy
    has_many :form_submissions, class_name: 'V7CMS::FormSubmission', dependent: :destroy

    validates :name, presence: true, length: { maximum: 255 }
    validates :slug, presence: true, uniqueness: true,
                     format: { with: /\A[a-z0-9-]+\z/, message: 'only allows lowercase letters, numbers, and hyphens' }
    validates :submit_button_text, presence: true
    validates :success_message, presence: true
    validates :notification_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: 'is invalid' },
                                   allow_blank: true
    validates :recaptcha_threshold, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
    validates :spam_behavior, inclusion: { in: %w[store reject] }

    scope :published, -> { where(published: true) }

    before_validation :generate_slug

    def validate_submission(data)
      errors = []
      form_fields.each do |field|
        value = data[field.name]

        field_label = field.label || field.name
        if field.required? && (value.to_s.strip.empty? || (field.field_type == 'checkbox' && value == 'false'))
          errors << "#{field_label} is required"
          next
        end

        next if value.to_s.strip.empty?

        case field.field_type
        when 'email'
          errors << "#{field_label} must be a valid email address" unless value.match?(URI::MailTo::EMAIL_REGEXP)
        when 'number'
          unless value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
            errors << "#{field_label} must be a number"
            next
          end
          rules = field.parsed_validation_rules
          num = value.to_f
          errors << "#{field_label} must be at least #{rules['min']}" if rules['min'] && num < rules['min'].to_f
          errors << "#{field_label} must be at most #{rules['max']}" if rules['max'] && num > rules['max'].to_f
        when 'url'
          errors << "#{field_label} must be a valid URL" unless value.match?(%r{\Ahttps?://\S+\z}i)
        when 'tel'
          errors << "#{field_label} must be a valid phone number" unless value.match?(/\A[\d\s()+.-]+\z/)
        end

        rules = field.parsed_validation_rules
        errors << "#{field_label} must be at least #{rules['min_length']} characters" if rules['min_length'] && value.length < rules['min_length'].to_i
        errors << "#{field_label} must be at most #{rules['max_length']} characters" if rules['max_length'] && value.length > rules['max_length'].to_i
        next unless rules['pattern']

        begin
          errors << "#{field_label} format is invalid" unless value.match?(Regexp.new(rules['pattern']))
        rescue RegexpError
          errors << "#{field_label} has an invalid validation pattern"
        end
      end
      errors
    end

    private

    def generate_slug
      return if slug.present? || name.blank?

      self.slug = name.downcase
                      .gsub(/[^a-z0-9\s-]/, '')
                      .gsub(/\s+/, '-').squeeze('-')
                      .strip
                      .gsub(/^-|-$/, '')
    end
  end
end
