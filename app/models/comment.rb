class Comment < ActiveRecord::Base
  belongs_to :post

  validates :author_name, presence: true, length: { maximum: 100 }
  validates :author_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 100 }
  validates :author_url, format: { with: URI::DEFAULT_PARSER.make_regexp(['http', 'https']) }, allow_blank: true
  validates :content, presence: true, length: { maximum: 5000 }

  scope :approved, -> { where(approved: true, spam: false) }
  scope :pending, -> { where(approved: false, spam: false) }
  scope :spam, -> { where(spam: true) }

  def self.pending_count
    pending.count
  end
end
