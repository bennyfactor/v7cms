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

      if ENV['SMTP_ADDRESS']
        Mail.defaults do
          delivery_method :smtp,
                          address: ENV['SMTP_ADDRESS'],
                          port: ENV.fetch('SMTP_PORT', 587).to_i,
                          user_name: ENV['SMTP_USERNAME'],
                          password: ENV['SMTP_PASSWORD'],
                          domain: ENV['SMTP_DOMAIN'],
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
      lines = []
      lines << "New submission for: #{@form.name}"
      lines << '=' * 40
      lines << ''

      @form.form_fields.each do |field|
        next if field.field_type == 'hidden'

        value = @data[field.name] || '(empty)'
        value = value == 'true' ? 'Yes' : 'No' if field.field_type == 'checkbox'
        lines << "#{field.label}: #{value}"
      end

      lines << ''
      lines << '-' * 40
      lines << "Submission ID: #{@submission&.id || 'N/A'}"
      lines << "Submitted at: #{@submission&.created_at&.iso8601 || Time.now.iso8601}"
      lines << "IP Address: #{@submission&.ip_address || 'Unknown'}"
      lines << "reCAPTCHA Score: #{@submission&.recaptcha_score || 'N/A'}"
      lines.join("\n")
    end
  end
end
