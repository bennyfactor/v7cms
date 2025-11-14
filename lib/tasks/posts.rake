namespace :posts do
  desc "Regenerate all static HTML files for published posts"
  task :regenerate_all => :environment do
    require_relative '../../app/services/post_renderer'

    published_posts = Post.published
    count = 0

    puts "Regenerating static files for #{published_posts.count} published posts..."

    published_posts.each do |post|
      PostRenderer.write_static_file(post)
      count += 1
      print "." if count % 10 == 0
    end

    puts "\nSuccessfully regenerated #{count} static files."
  end

  desc "Clean orphaned static HTML files (files without corresponding posts)"
  task :clean_orphans => :environment do
    require_relative '../../app/services/post_renderer'

    static_dir = PostRenderer::STATIC_DIR
    unless Dir.exist?(static_dir)
      puts "Static directory does not exist: #{static_dir}"
      next
    end

    html_files = Dir.glob(File.join(static_dir, '*.html'))
    removed_count = 0

    puts "Checking #{html_files.count} static files for orphans..."

    html_files.each do |file_path|
      filename = File.basename(file_path, '.html')
      post = Post.find_by(slug: filename)

      if post.nil? || !post.published?
        File.delete(file_path)
        removed_count += 1
        puts "Removed: #{filename}.html (#{post.nil? ? 'post not found' : 'post not published'})"
      end
    end

    if removed_count > 0
      puts "Cleaned up #{removed_count} orphaned file(s)."
    else
      puts "No orphaned files found."
    end
  end

  desc "Verify all published posts have static files"
  task :verify => :environment do
    require_relative '../../app/services/post_renderer'

    published_posts = Post.published
    missing_count = 0

    puts "Verifying static files for #{published_posts.count} published posts..."

    published_posts.each do |post|
      file_path = File.join(PostRenderer::STATIC_DIR, "#{post.slug}.html")

      unless File.exist?(file_path)
        missing_count += 1
        puts "Missing: #{post.slug}.html (Post ID: #{post.id}, Title: #{post.title})"
      end
    end

    if missing_count > 0
      puts "\n#{missing_count} published post(s) are missing static files."
      puts "Run 'rake posts:regenerate_all' to generate missing files."
    else
      puts "\nAll published posts have static files. ✓"
    end
  end
end
