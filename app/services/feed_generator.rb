require 'builder'
require 'fileutils'
require 'logger'

class FeedGenerator
  FEED_LIMIT = 20

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.generate_rss
    new.generate_rss
  end

  def self.generate_atom
    new.generate_atom
  end

  def self.write_feeds
    new.write_feeds
  end

  def initialize(base_url: nil)
    @settings = Setting.instance
    @posts = Post.published.recent.limit(FEED_LIMIT)
    @base_url = base_url
  end

  def generate_rss
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'

    xml.rss version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom' do
      xml.channel do
        xml.title @settings.site_title
        xml.description @settings.meta_description
        xml.link site_url
        xml.language 'en-us'
        xml.lastBuildDate Time.now.rfc822
        xml.tag! 'atom:link', href: "#{site_url}/feed/rss", rel: 'self', type: 'application/rss+xml'

        @posts.each do |post|
          xml.item do
            xml.title post.title
            xml.link post_url(post)
            xml.description post.content
            xml.pubDate post.created_at.rfc822
            xml.guid post_url(post), isPermaLink: 'true'
          end
        end
      end
    end
  end

  def generate_atom
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'

    xml.feed xmlns: 'http://www.w3.org/2005/Atom' do
      xml.title @settings.site_title
      xml.subtitle @settings.meta_description
      xml.link href: site_url
      xml.link href: "#{site_url}/feed/atom", rel: 'self'
      xml.id site_url
      xml.updated(@posts.first&.updated_at&.iso8601 || Time.now.iso8601)

      if @settings.site_author.present?
        xml.author do
          xml.name @settings.site_author
        end
      end

      @posts.each do |post|
        xml.entry do
          xml.title post.title
          xml.link href: post_url(post)
          xml.id post_url(post)
          xml.published post.created_at.iso8601
          xml.updated post.updated_at.iso8601
          xml.content post.content, type: 'html'
        end
      end
    end
  end

  def write_feeds
    ensure_public_directory_exists

    rss_success = write_rss_feed
    atom_success = write_atom_feed

    rss_success && atom_success
  end

  private

  def write_rss_feed
    begin
      File.write(rss_file_path, generate_rss)
      self.class.logger.info("Generated RSS feed")
      true
    rescue => e
      self.class.logger.error("Failed to generate RSS feed: #{e.message}")
      self.class.logger.error(e.backtrace.join("\n"))
      false
    end
  end

  def write_atom_feed
    begin
      File.write(atom_file_path, generate_atom)
      self.class.logger.info("Generated Atom feed")
      true
    rescue => e
      self.class.logger.error("Failed to generate Atom feed: #{e.message}")
      self.class.logger.error(e.backtrace.join("\n"))
      false
    end
  end

  def site_url
    @base_url || ENV.fetch('SITE_URL', 'http://localhost:9292')
  end

  def post_url(post)
    "#{site_url}/posts/#{post.slug}"
  end

  def rss_file_path
    File.join(Dir.pwd, 'public', 'feed.xml')
  end

  def atom_file_path
    File.join(Dir.pwd, 'public', 'atom.xml')
  end

  def ensure_public_directory_exists
    public_dir = File.join(Dir.pwd, 'public')
    FileUtils.mkdir_p(public_dir) unless Dir.exist?(public_dir)
  end
end
