# frozen_string_literal: true

require 'mail'

module V7CMS
  class FormMailer
    def self.logger
      @logger ||= Logger.new($stdout)
    end

    def self.send_notification(form, data, submission = nil)
      new(form, data, submission).send_notification
    end

    def initialize(form, data, submission = nil)
      @form = form
      @data = data
      @submission = submission
    end

    def send_notification
      return unless @form.send_notifications
      return if @form.notification_email.to_s.strip.empty?

      configure_mail_delivery
      deliver_email
    rescue StandardError => e
      self.class.logger.error("FormMailer: Failed to send notification for form #{@form.id}: #{e.message}")
    end

    private

    def configure_mail_delivery
      return if ENV['RACK_ENV'] == 'test'

      if ENV.fetch('SMTP_ADDRESS', nil)
        Mail.defaults do
          delivery_method :smtp,
                          address: ENV.fetch('SMTP_ADDRESS', nil),
                          port: ENV.fetch('SMTP_PORT', 587).to_i,
                          user_name: ENV.fetch('SMTP_USERNAME', nil),
                          password: ENV.fetch('SMTP_PASSWORD', nil),
                          domain: ENV.fetch('SMTP_DOMAIN', nil),
                          authentication: ENV.fetch('SMTP_AUTH', 'plain'),
                          enable_starttls_auto: ENV.fetch('SMTP_TLS', 'true') == 'true'
        end
      else
        Mail.defaults { delivery_method :sendmail }
      end
    end

    def deliver_email
      from_address = from_email
      to_address = @form.notification_email
      subject_line = "New submission: #{@form.name}"
      body_text = build_body

      Mail.new do
        from    from_address
        to      to_address
        subject subject_line
        body    body_text
      end.deliver
    end

    def from_email
      contact = begin
        V7CMS::Setting.get(:contact_email)
      rescue StandardError
        nil
      end
      contact.presence || @form.notification_email
    end

    def build_body
      lines = build_body_header
      lines.concat(build_body_fields)
      lines.concat(build_body_footer)
      lines.join("\n")
    end

    def build_body_header
      ["New submission for: #{@form.name}", '=' * 40, '']
    end

    def build_body_fields
      @form.form_fields.each_with_object([]) do |field, lines|
        next if field.field_type == 'hidden'

        value = @data[field.name] || '(empty)'
        value = (value == 'true' ? 'Yes' : 'No') if field.field_type == 'checkbox'
        lines << "#{field.label}: #{value}"
      end
    end

    def build_body_footer
      [
        '',
        '-' * 40,
        "Submission ID: #{@submission&.id || 'N/A'}",
        "Submitted at: #{@submission&.created_at&.iso8601 || Time.now.iso8601}",
        "IP Address: #{@submission&.ip_address || 'Unknown'}",
        "reCAPTCHA Score: #{@submission&.recaptcha_score || 'N/A'}",
      ]
    end
  end
end
