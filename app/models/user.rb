class User < ActiveRecord::Base
  validates :email, presence: true
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :admin, inclusion: { in: [true, false] }

  after_create :fetch_gravatar_if_missing

  def self.from_omniauth(auth_hash)
    where(provider: auth_hash['provider'], uid: auth_hash['uid']).first_or_create do |user|
      user.email = auth_hash['info']['email']
      user.name = auth_hash['info']['name']
      user.avatar_url = auth_hash['info']['image']
    end
  end

  def fetch_gravatar_if_missing
    return if avatar_url.present? && name.present?

    gravatar_data = GravatarService.fetch_profile(email)
    return if gravatar_data.empty?

    updates = {}
    updates[:avatar_url] = gravatar_data[:avatar_url] if avatar_url.blank? && gravatar_data[:avatar_url]
    updates[:name] = gravatar_data[:name] if name.blank? && gravatar_data[:name]

    update_columns(updates) if updates.any?
  end
end
