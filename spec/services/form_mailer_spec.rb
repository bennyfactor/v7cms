# frozen_string_literal: true

require 'spec_helper'
require 'mail'

RSpec.describe V7CMS::FormMailer do
  let(:form) do
    V7CMS::Form.create!(
      name: 'Contact Form',
      slug: 'contact',
      notification_email: 'admin@example.com',
      send_notifications: true
    )
  end

  let(:data) { { 'full_name' => 'John Doe', 'email' => 'john@example.com', 'message' => 'Hello!' } }
  let(:submission) do
    V7CMS::FormSubmission.create!(form: form, data: data.to_json, ip_address: '1.2.3.4', recaptcha_score: 0.9)
  end

  before do
    form.form_fields.create!(field_type: 'text', name: 'full_name', label: 'Full Name', position: 0)
    form.form_fields.create!(field_type: 'email', name: 'email', label: 'Email', position: 1)
    form.form_fields.create!(field_type: 'textarea', name: 'message', label: 'Message', position: 2)
    Mail.defaults { delivery_method :test }
  end

  after { Mail::TestMailer.deliveries.clear }

  describe '.send_notification' do
    it 'sends email to notification_email' do
      described_class.send_notification(form, data, submission)
      expect(Mail::TestMailer.deliveries.length).to eq(1)
      mail = Mail::TestMailer.deliveries.first
      expect(mail.to).to eq(['admin@example.com'])
    end

    it 'includes form name in subject' do
      described_class.send_notification(form, data, submission)
      mail = Mail::TestMailer.deliveries.first
      expect(mail.subject).to eq('New submission: Contact Form')
    end

    it 'includes field values in body' do
      described_class.send_notification(form, data, submission)
      mail = Mail::TestMailer.deliveries.first
      body = mail.body.to_s
      expect(body).to include('Full Name: John Doe')
      expect(body).to include('Email: john@example.com')
      expect(body).to include('Message: Hello!')
    end

    it 'includes submission metadata in body' do
      described_class.send_notification(form, data, submission)
      body = Mail::TestMailer.deliveries.first.body.to_s
      expect(body).to include("Submission ID: #{submission.id}")
      expect(body).to include('IP Address: 1.2.3.4')
    end

    it 'does not send when send_notifications is false' do
      form.update!(send_notifications: false)
      described_class.send_notification(form, data, submission)
      expect(Mail::TestMailer.deliveries).to be_empty
    end

    it 'does not send when notification_email is blank' do
      form.update!(notification_email: '')
      described_class.send_notification(form, data, submission)
      expect(Mail::TestMailer.deliveries).to be_empty
    end

    it 'handles mail delivery errors gracefully' do
      mail_message = instance_double(Mail::Message)
      allow(mail_message).to receive(:delivery_method)
      allow(mail_message).to receive(:deliver).and_raise(StandardError.new('SMTP error'))
      allow(Mail).to receive(:new).and_return(mail_message)
      expect { described_class.send_notification(form, data, submission) }.not_to raise_error
    end
  end
end
