module V7CMS
  class Setting < ActiveRecord::Base
    # Singleton pattern - only one settings record should exist

    # Class variables for caching
    @@instance_cache = nil
    @@cache_mutex = Mutex.new

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
      with: /\A(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([\/\w .-]*)*\/?\z/i,
      allow_blank: true,
      message: 'must be a valid URL'
    }

    validates :posts_per_page, numericality: {
      only_integer: true,
      greater_than: 0,
      less_than_or_equal_to: 100
    }

    validates :max_upload_size, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1_048_576,      # 1 MB
      less_than_or_equal_to: 104_857_600        # 100 MB
    }

    validates :date_format, presence: true

    validates :allow_comments, inclusion: { in: [true, false] }

    validates :reserved_redirect_paths, length: { maximum: 1000 }

    # Built-in homepage layouts (shipped with gem)
    HOMEPAGE_LAYOUTS = %w[blog_list blog_grid hero_grid magazine minimal portfolio landing].freeze

    # Built-in post layouts (shipped with gem)
    POST_LAYOUTS = %w[standard magazine minimal full_width].freeze

    # Validate layout_homepage against all available layouts (built-in + custom)
    validate :layout_homepage_must_be_available
    validate :layout_post_must_be_available

    # Discover all available homepage layouts from both gem and user views
    def self.available_layouts
      layouts = HOMEPAGE_LAYOUTS.dup

      # Get all view paths (user's project + gem)
      views_paths = V7CMS.file_resolver.resolve_all('views')

      views_paths.each do |views_path|
        layout_dir = File.join(views_path, 'layouts', 'homepage')
        next unless File.directory?(layout_dir)

        Dir.glob(File.join(layout_dir, '_*.erb')).each do |file|
          # Extract layout name from _name.erb
          name = File.basename(file, '.erb').sub(/^_/, '')
          layouts << name unless layouts.include?(name)
        end
      end

      layouts.sort
    end

    # Discover all available post layouts from both gem and user views
    # Partials that should not be listed as layouts
    POST_LAYOUT_PARTIALS = %w[comments].freeze

    def self.available_post_layouts
      layouts = POST_LAYOUTS.dup

      # Get all view paths (user's project + gem)
      views_paths = V7CMS.file_resolver.resolve_all('views')

      views_paths.each do |views_path|
        layout_dir = File.join(views_path, 'layouts', 'post')
        next unless File.directory?(layout_dir)

        Dir.glob(File.join(layout_dir, '_*.erb')).each do |file|
          # Extract layout name from _name.erb
          name = File.basename(file, '.erb').sub(/^_/, '')
          # Skip partials that aren't actual layouts
          next if POST_LAYOUT_PARTIALS.include?(name)
          layouts << name unless layouts.include?(name)
        end
      end

      layouts.sort
    end

    # Callbacks
    after_commit :regenerate_feeds
    after_save :clear_instance_cache

    # Singleton instance method with caching
    def self.instance
      # Quick check outside mutex for performance
      return @@instance_cache if @@instance_cache

      # Load instance outside mutex to avoid deadlock with after_save callback
      instance = first_or_create!

      # Thread-safe cache assignment
      @@cache_mutex.synchronize do
        # Double-check inside mutex (another thread may have initialized)
        @@instance_cache ||= instance
      end

      @@instance_cache
    end

    # Clear the instance cache
    def self.clear_cache!
      @@cache_mutex.synchronize do
        @@instance_cache = nil
      end
    end

    # Convenience method to get a setting value
    def self.get(key)
      instance.send(key) if instance.respond_to?(key)
    end

    # Get reserved redirect paths as an array
    def reserved_paths_array
      return [] if reserved_redirect_paths.blank?
      reserved_redirect_paths.split(',').map(&:strip).reject(&:empty?)
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
        date_format: '%B %d, %Y',
        allow_comments: true,
        reserved_redirect_paths: '/,/admin,/api,/auth,/feed,/posts,/pages',
        layout_homepage: 'blog_list',
        layout_post: 'standard',
        max_upload_size: 10_485_760
      )
    end

    private

    def layout_homepage_must_be_available
      return if layout_homepage.blank?

      available = self.class.available_layouts
      errors.add(:layout_homepage, "must be a valid layout option (available: #{available.join(', ')})") unless available.include?(layout_homepage)
    end

    def layout_post_must_be_available
      return if layout_post.blank?

      available = self.class.available_post_layouts
      errors.add(:layout_post, "must be a valid layout option (available: #{available.join(', ')})") unless available.include?(layout_post)
    end

    def regenerate_feeds
      FeedGenerator.write_feeds
    end

    def clear_instance_cache
      self.class.clear_cache!
    end
  end
end
