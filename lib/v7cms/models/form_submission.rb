# frozen_string_literal: true

module V7CMS
  class FormSubmission < ActiveRecord::Base
    belongs_to :form, class_name: 'V7CMS::Form', optional: false

    validates :data, presence: true

    scope :not_spam, -> { where(spam: false) }
    scope :spam, -> { where(spam: true) }

    def parsed_data
      return {} if data.blank?

      JSON.parse(data)
    rescue JSON::ParserError
      {}
    end
  end
end
