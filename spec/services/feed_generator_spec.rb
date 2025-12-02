require_relative '../spec_helper'
require 'nokogiri'

RSpec.describe FeedGenerator do
  let!(:setting) do
    Setting.instance.tap do |s|
      s.update!(
        site_title: 'Test Blog',
        meta_description: 'A test blog for RSS feeds',
        site_author: 'Test Author'
      )
    end
  end

  let!(:posts) do
    3.times.map do |i|
      Post.create!(
        title: "Test Post #{i + 1}",
        slug: "test-post-#{i + 1}",
        content: "<p>This is test post #{i + 1} content.</p>",
        published: true,
        created_at: Time.now - (i * 3600) # Stagger creation times
      )
    end
  end

  before do
    # Clean up any existing feed files
    FileUtils.rm_f(File.join(Dir.pwd, 'public', 'feed.xml'))
    FileUtils.rm_f(File.join(Dir.pwd, 'public', 'atom.xml'))
  end

  after do
    # Clean up generated feed files
    FileUtils.rm_f(File.join(Dir.pwd, 'public', 'feed.xml'))
    FileUtils.rm_f(File.join(Dir.pwd, 'public', 'atom.xml'))
  end

  describe '#generate_rss' do
    it 'generates valid XML' do
      rss = FeedGenerator.generate_rss
      expect { Nokogiri::XML(rss) { |config| config.strict } }.not_to raise_error
    end

    it 'includes RSS 2.0 declaration' do
      rss = FeedGenerator.generate_rss
      expect(rss).to include('<rss version="2.0"')
    end

    it 'includes Atom namespace' do
      rss = FeedGenerator.generate_rss
      expect(rss).to include('xmlns:atom="http://www.w3.org/2005/Atom"')
    end

    it 'includes channel title from settings' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      title = doc.at_xpath('//channel/title').text
      expect(title).to eq('Test Blog')
    end

    it 'includes channel description from settings' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      description = doc.at_xpath('//channel/description').text
      expect(description).to eq('A test blog for RSS feeds')
    end

    it 'includes channel link' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      link = doc.at_xpath('//channel/link').text
      expect(link).to match(/http/)
    end

    it 'includes language tag' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      language = doc.at_xpath('//channel/language').text
      expect(language).to eq('en-us')
    end

    it 'includes lastBuildDate' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      last_build_date = doc.at_xpath('//channel/lastBuildDate')
      expect(last_build_date).not_to be_nil
    end

    it 'includes atom:link for self-reference' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      atom_link = doc.at_xpath('//channel/atom:link[@rel="self"]', 'atom' => 'http://www.w3.org/2005/Atom')
      expect(atom_link).not_to be_nil
      expect(atom_link['type']).to eq('application/rss+xml')
    end

    it 'includes items for published posts' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      items = doc.xpath('//item')
      expect(items.count).to eq(3)
    end

    it 'includes item title' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      first_item_title = doc.xpath('//item/title').first.text
      expect(first_item_title).to eq('Test Post 1')
    end

    it 'includes item link' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      first_item_link = doc.xpath('//item/link').first.text
      expect(first_item_link).to include('/posts/test-post-1')
    end

    it 'includes item description with HTML content' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      first_item_description = doc.xpath('//item/description').first.text
      expect(first_item_description).to include('This is test post 1 content')
    end

    it 'includes item pubDate in RFC 822 format' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      first_item_pub_date = doc.xpath('//item/pubDate').first.text
      expect(first_item_pub_date).to match(/\w{3}, \d{2} \w{3} \d{4}/)
    end

    it 'includes item guid' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      first_item_guid = doc.xpath('//item/guid').first.text
      expect(first_item_guid).to include('/posts/test-post-1')
    end

    it 'marks guid as permalink' do
      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      first_item_guid_node = doc.xpath('//item/guid').first
      expect(first_item_guid_node['isPermaLink']).to eq('true')
    end

    it 'only includes published posts' do
      draft = Post.create!(
        title: 'Draft Post',
        slug: 'draft-post',
        content: '<p>Draft content</p>',
        published: false
      )

      rss = FeedGenerator.generate_rss
      expect(rss).not_to include('Draft Post')
    end

    it 'limits to most recent 20 posts' do
      # Create 25 posts (we already have 3)
      22.times do |i|
        Post.create!(
          title: "Extra Post #{i}",
          slug: "extra-post-#{i}",
          content: '<p>Extra content</p>',
          published: true
        )
      end

      rss = FeedGenerator.generate_rss
      doc = Nokogiri::XML(rss)
      items = doc.xpath('//item')
      expect(items.count).to eq(20)
    end
  end

  describe '#generate_atom' do
    it 'generates valid XML' do
      atom = FeedGenerator.generate_atom
      expect { Nokogiri::XML(atom) { |config| config.strict } }.not_to raise_error
    end

    it 'includes Atom namespace' do
      atom = FeedGenerator.generate_atom
      expect(atom).to include('xmlns="http://www.w3.org/2005/Atom"')
    end

    it 'includes feed title from settings' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      title = doc.at_xpath('//xmlns:feed/xmlns:title', 'xmlns' => 'http://www.w3.org/2005/Atom').text
      expect(title).to eq('Test Blog')
    end

    it 'includes feed subtitle from settings' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      subtitle = doc.at_xpath('//xmlns:feed/xmlns:subtitle', 'xmlns' => 'http://www.w3.org/2005/Atom').text
      expect(subtitle).to eq('A test blog for RSS feeds')
    end

    it 'includes feed link' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      link = doc.at_xpath('//xmlns:feed/xmlns:link[not(@rel="self")]', 'xmlns' => 'http://www.w3.org/2005/Atom')
      expect(link['href']).to match(/http/)
    end

    it 'includes self link' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      self_link = doc.at_xpath('//xmlns:feed/xmlns:link[@rel="self"]', 'xmlns' => 'http://www.w3.org/2005/Atom')
      expect(self_link['href']).to include('/feed/atom')
    end

    it 'includes feed id' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      feed_id = doc.at_xpath('//xmlns:feed/xmlns:id', 'xmlns' => 'http://www.w3.org/2005/Atom')
      expect(feed_id).not_to be_nil
    end

    it 'includes feed updated timestamp in ISO 8601 format' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      updated = doc.at_xpath('//xmlns:feed/xmlns:updated', 'xmlns' => 'http://www.w3.org/2005/Atom').text
      expect(updated).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it 'includes author when site_author is present' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      author_name = doc.at_xpath('//xmlns:feed/xmlns:author/xmlns:name', 'xmlns' => 'http://www.w3.org/2005/Atom').text
      expect(author_name).to eq('Test Author')
    end

    it 'includes entries for published posts' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      entries = doc.xpath('//xmlns:entry', 'xmlns' => 'http://www.w3.org/2005/Atom')
      expect(entries.count).to eq(3)
    end

    it 'includes entry title' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      first_entry_title = doc.xpath('//xmlns:entry/xmlns:title', 'xmlns' => 'http://www.w3.org/2005/Atom').first.text
      expect(first_entry_title).to eq('Test Post 1')
    end

    it 'includes entry link' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      first_entry_link = doc.xpath('//xmlns:entry/xmlns:link', 'xmlns' => 'http://www.w3.org/2005/Atom').first
      expect(first_entry_link['href']).to include('/posts/test-post-1')
    end

    it 'includes entry id' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      first_entry_id = doc.xpath('//xmlns:entry/xmlns:id', 'xmlns' => 'http://www.w3.org/2005/Atom').first.text
      expect(first_entry_id).to include('/posts/test-post-1')
    end

    it 'includes entry published timestamp in ISO 8601 format' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      first_entry_published = doc.xpath('//xmlns:entry/xmlns:published', 'xmlns' => 'http://www.w3.org/2005/Atom').first.text
      expect(first_entry_published).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it 'includes entry updated timestamp in ISO 8601 format' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      first_entry_updated = doc.xpath('//xmlns:entry/xmlns:updated', 'xmlns' => 'http://www.w3.org/2005/Atom').first.text
      expect(first_entry_updated).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it 'includes entry content with HTML' do
      atom = FeedGenerator.generate_atom
      doc = Nokogiri::XML(atom)
      first_entry_content = doc.xpath('//xmlns:entry/xmlns:content', 'xmlns' => 'http://www.w3.org/2005/Atom').first
      expect(first_entry_content.text).to include('This is test post 1 content')
      expect(first_entry_content['type']).to eq('html')
    end
  end

  describe '#write_feeds' do
    it 'writes RSS feed to public/feed.xml' do
      FeedGenerator.write_feeds

      feed_path = File.join(Dir.pwd, 'public', 'feed.xml')
      expect(File.exist?(feed_path)).to be true
    end

    it 'writes Atom feed to public/atom.xml' do
      FeedGenerator.write_feeds

      atom_path = File.join(Dir.pwd, 'public', 'atom.xml')
      expect(File.exist?(atom_path)).to be true
    end

    it 'creates public directory if it does not exist' do
      public_dir = File.join(Dir.pwd, 'public')
      FileUtils.rm_rf(public_dir) if Dir.exist?(public_dir)

      FeedGenerator.write_feeds

      expect(Dir.exist?(public_dir)).to be true
    end

    it 'overwrites existing feed files' do
      FeedGenerator.write_feeds
      original_rss = File.read(File.join(Dir.pwd, 'public', 'feed.xml'))

      # Change a setting
      setting.update!(site_title: 'Updated Blog')
      FeedGenerator.write_feeds

      updated_rss = File.read(File.join(Dir.pwd, 'public', 'feed.xml'))
      expect(updated_rss).not_to eq(original_rss)
      expect(updated_rss).to include('Updated Blog')
    end
  end

  describe '.generate_rss' do
    it 'returns RSS XML string' do
      rss = FeedGenerator.generate_rss
      expect(rss).to be_a(String)
      expect(rss).to include('<rss version="2.0"')
    end
  end

  describe '.generate_atom' do
    it 'returns Atom XML string' do
      atom = FeedGenerator.generate_atom
      expect(atom).to be_a(String)
      expect(atom).to include('xmlns="http://www.w3.org/2005/Atom"')
    end
  end

  describe '.write_feeds' do
    it 'writes both feeds' do
      FeedGenerator.write_feeds

      expect(File.exist?(File.join(Dir.pwd, 'public', 'feed.xml'))).to be true
      expect(File.exist?(File.join(Dir.pwd, 'public', 'atom.xml'))).to be true
    end
  end

  describe 'error handling' do
    let!(:post) { Post.create!(title: 'Test', slug: 'test', content: 'Content', published: true) }

    describe '#write_feeds' do
      it 'returns true when both feed writes succeed' do
        generator = FeedGenerator.new
        result = generator.write_feeds
        expect(result).to be true
      end

      it 'returns false when RSS write fails' do
        generator = FeedGenerator.new
        allow(File).to receive(:write).with(/feed\.xml/, anything).and_raise(Errno::EACCES, 'Permission denied')
        allow(File).to receive(:write).with(/atom\.xml/, anything).and_return(true)

        result = generator.write_feeds
        expect(result).to be false
      end

      it 'returns false when Atom write fails' do
        generator = FeedGenerator.new
        allow(File).to receive(:write).with(/feed\.xml/, anything).and_return(true)
        allow(File).to receive(:write).with(/atom\.xml/, anything).and_raise(Errno::EACCES, 'Permission denied')

        result = generator.write_feeds
        expect(result).to be false
      end

      it 'logs error when RSS write fails' do
        generator = FeedGenerator.new
        logger = instance_double(Logger)
        allow(FeedGenerator).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(/RSS.*Permission denied/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(File).to receive(:write).with(/feed\.xml/, anything).and_raise(Errno::EACCES, 'Permission denied')
        allow(File).to receive(:write).with(/atom\.xml/, anything).and_return(true)

        generator.write_feeds
      end

      it 'logs error when Atom write fails' do
        generator = FeedGenerator.new
        logger = instance_double(Logger)
        allow(FeedGenerator).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(/Atom.*Permission denied/)
        expect(logger).to receive(:error).with(kind_of(String))  # backtrace
        allow(File).to receive(:write).with(/feed\.xml/, anything).and_return(true)
        allow(File).to receive(:write).with(/atom\.xml/, anything).and_raise(Errno::EACCES, 'Permission denied')

        generator.write_feeds
      end

      it 'attempts both writes even if first fails' do
        generator = FeedGenerator.new
        allow(File).to receive(:write).with(/feed\.xml/, anything).and_raise(Errno::EACCES)
        expect(File).to receive(:write).with(/atom\.xml/, anything)

        generator.write_feeds
      end
    end

    describe 'class method wrapper' do
      it 'write_feeds returns boolean from instance method' do
        allow_any_instance_of(FeedGenerator).to receive(:write_feeds).and_return(false)
        result = FeedGenerator.write_feeds
        expect(result).to be false
      end
    end
  end
end
