require 'builder'
require 'fileutils'

class FeedGenerator
  FEED_LIMIT = 20

  def self.generate_rss
    new.generate_rss
  end

  def self.generate_atom
    new.generate_atom
  end

  def self.write_feeds
    new.write_feeds
  end

  def initialize
    @settings = Setting.instance
    @posts = Post.published.recent.limit(FEED_LIMIT)
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
        xml.tag! 'atom:link', href: "#{site_url}/feed.xml", rel: 'self', type: 'application/rss+xml'

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
      xml.link href: "#{site_url}/atom.xml", rel: 'self'
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
    File.write(rss_file_path, generate_rss)
    File.write(atom_file_path, generate_atom)
  end

  private

  def site_url
    # In production, this should come from settings or environment
    # For now, use a sensible default
    ENV.fetch('SITE_URL', 'http://localhost:9292')
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
