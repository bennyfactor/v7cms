class Setting < ActiveRecord::Base
  # Singleton pattern - only one settings record should exist

  # Validations
  validates :site_title, presence: true, length: { maximum: 100 }
  validates :site_tagline, length: { maximum: 200 }
  validates :site_author, length: { maximum: 100 }

  validates :welcome_title, presence: true, length: { maximum: 200 }
  validates :welcome_subtitle, length: { maximum: 300 }

  validates :footer_text, length: { maximum: 300 }

  validates :meta_keywords, length: { maximum: 500 }

  validates :contact_email, format: {
    with: URI::MailTo::EMAIL_REGEXP,
    allow_blank: true,
    message: 'must be a valid email address'
  }

  validates :github_url, :social_url, format: {
    with: /\A(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?\z/i,
    allow_blank: true,
    message: 'must be a valid URL'
  }

  validates :posts_per_page, numericality: {
    only_integer: true,
    greater_than: 0,
    less_than_or_equal_to: 100
  }

  validates :date_format, presence: true

  # Feed regeneration callback
  after_commit :regenerate_feeds

  # Singleton instance method
  def self.instance
    first_or_create!
  end

  # Convenience method to get a setting value
  def self.get(key)
    instance.send(key) if instance.respond_to?(key)
  end

  # Reset to default values
  def reset_to_defaults!
    update!(
      site_title: 'v7cms',
      site_tagline: 'A minimal, modern content management system',
      site_author: '',
      welcome_title: 'Welcome to v7cms',
      welcome_subtitle: 'A minimal, modern content management system',
      footer_text: 'Powered by v7cms',
      show_copyright_year: true,
      meta_description: 'A minimal, modern content management system built with Ruby and Sinatra',
      meta_keywords: '',
      contact_email: '',
      github_url: '',
      social_url: '',
      posts_per_page: 10,
      date_format: '%B %d, %Y'
    )
  end

  private

  def regenerate_feeds
    FeedGenerator.write_feeds
  end
end
