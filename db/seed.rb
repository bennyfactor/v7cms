require 'sinatra/activerecord'
require 'yaml'
require_relative '../app/models/post'
require_relative '../app/models/setting'

db_config = YAML.load_file('config/database.yml')['development']
ActiveRecord::Base.establish_connection(db_config)

# Create sample posts
Post.create!(
  title: 'Welcome to v7cms',
  slug: 'welcome',
  content: '<h2>Getting Started</h2><p>This is a minimal, modern content management system built with Ruby, Sinatra, and modern web technologies.</p><p>Features include:</p><ul><li>OAuth authentication (Google & GitHub)</li><li>RESTful API</li><li>WYSIWYG editor with Quill.js</li><li>Tailwind CSS styling</li><li>Alpine.js for interactivity</li></ul>',
  published: true
)

Post.create!(
  title: 'About This CMS',
  slug: 'about',
  content: '<h2>Technology Stack</h2><p>v7cms is built with:</p><ul><li><strong>Backend:</strong> Ruby 3.4 with Sinatra framework</li><li><strong>Database:</strong> SQLite with ActiveRecord ORM</li><li><strong>Authentication:</strong> OmniAuth 2.0</li><li><strong>Frontend:</strong> Alpine.js, Tailwind CSS standalone, Quill.js</li></ul><p>The entire system is containerized with Docker for easy deployment.</p>',
  published: true
)

puts 'Created 2 sample posts!'
Post.all.each { |p| puts "  - #{p.title} (#{p.slug})" }

# Ensure settings exist with defaults
Setting.instance
puts 'Settings initialized with default values'
