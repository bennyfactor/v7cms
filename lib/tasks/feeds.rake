namespace :feeds do
  desc "Regenerate RSS and Atom feeds"
  task :regenerate => :environment do
    require_relative '../../app/services/feed_generator'

    puts "Regenerating RSS and Atom feeds..."

    FeedGenerator.write_feeds

    puts "✓ Generated public/feed.xml (RSS 2.0)"
    puts "✓ Generated public/atom.xml (Atom)"
    puts "\nFeeds successfully regenerated."
  end
end
