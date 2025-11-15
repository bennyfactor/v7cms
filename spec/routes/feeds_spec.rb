require_relative '../spec_helper'

RSpec.describe 'Feed Routes', type: :request do
  before do
    # Clean up any existing feeds
    FileUtils.rm_f(File.join(Dir.pwd, 'public', 'feed.xml'))
    FileUtils.rm_f(File.join(Dir.pwd, 'public', 'atom.xml'))

    # Create test posts
    @post1 = Post.create!(
      title: 'First Post',
      slug: 'first-post',
      content: '<p>This is the first post content.</p>',
      published: true
    )

    @post2 = Post.create!(
      title: 'Second Post',
      slug: 'second-post',
      content: '<p>This is the second post content.</p>',
      published: true
    )

    # Generate feeds
    FeedGenerator.write_feeds
  end

  after do
    # Clean up test feeds
    FileUtils.rm_f(File.join(Dir.pwd, 'public', 'feed.xml'))
    FileUtils.rm_f(File.join(Dir.pwd, 'public', 'atom.xml'))
  end

  describe 'GET /feed.xml' do
    it 'returns RSS feed with correct content type' do
      get '/feed.xml'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/rss+xml')
    end

    it 'serves the generated RSS feed file' do
      get '/feed.xml'

      expect(last_response.body).to include('<?xml version="1.0" encoding="UTF-8"?>')
      expect(last_response.body).to include('<rss version="2.0"')
      expect(last_response.body).to include('First Post')
      expect(last_response.body).to include('Second Post')
    end

    it 'returns 404 when feed file does not exist' do
      FileUtils.rm_f(File.join(Dir.pwd, 'public', 'feed.xml'))

      get '/feed.xml'

      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('Feed not found')
    end
  end

  describe 'GET /atom.xml' do
    it 'returns Atom feed with correct content type' do
      get '/atom.xml'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/atom+xml')
    end

    it 'serves the generated Atom feed file' do
      get '/atom.xml'

      expect(last_response.body).to include('<?xml version="1.0" encoding="UTF-8"?>')
      expect(last_response.body).to include('<feed xmlns="http://www.w3.org/2005/Atom">')
      expect(last_response.body).to include('First Post')
      expect(last_response.body).to include('Second Post')
    end

    it 'returns 404 when feed file does not exist' do
      FileUtils.rm_f(File.join(Dir.pwd, 'public', 'atom.xml'))

      get '/atom.xml'

      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('Feed not found')
    end
  end
end
