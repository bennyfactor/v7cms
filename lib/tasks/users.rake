namespace :users do
  desc "Backfill missing user data from Gravatar"
  task backfill_gravatar: :environment do
    users = User.where(avatar_url: [nil, '']).or(User.where(name: [nil, '']))

    puts "Found #{users.count} users with missing data"

    users.find_each do |user|
      before_avatar = user.avatar_url
      before_name = user.name

      user.fetch_gravatar_if_missing

      user.reload
      updated = []
      updated << "avatar" if user.avatar_url.present? && before_avatar.blank?
      updated << "name" if user.name.present? && before_name.blank?

      status = updated.any? ? "updated (#{updated.join(', ')})" : "no gravatar"
      puts "  #{user.email}: #{status}"
    end

    puts "Done."
  end
end
