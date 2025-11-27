class User < ActiveRecord::Base
  validates :email, presence: true
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :admin, inclusion: { in: [true, false] }

  def self.from_omniauth(auth_hash)
    where(provider: auth_hash['provider'], uid: auth_hash['uid']).first_or_create do |user|
      user.email = auth_hash['info']['email']
      user.name = auth_hash['info']['name']
      user.avatar_url = auth_hash['info']['image']
    end
  end
end
