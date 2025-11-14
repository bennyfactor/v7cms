class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      # Site Identity
      t.string :site_title, default: 'v7cms', null: false, limit: 100
      t.string :site_tagline, default: 'A minimal, modern content management system', limit: 200
      t.string :site_author, default: '', limit: 100

      # Homepage Content
      t.string :welcome_title, default: 'Welcome to v7cms', null: false, limit: 200
      t.string :welcome_subtitle, default: 'A minimal, modern content management system', limit: 300

      # Footer
      t.string :footer_text, default: 'Powered by v7cms', limit: 300
      t.boolean :show_copyright_year, default: true

      # SEO / Meta Tags
      t.text :meta_description, default: 'A minimal, modern content management system built with Ruby and Sinatra'
      t.string :meta_keywords, default: '', limit: 500

      # Contact & Social
      t.string :contact_email, default: '', limit: 100
      t.string :github_url, default: '', limit: 200
      t.string :social_url, default: '', limit: 200

      # Display Options
      t.integer :posts_per_page, default: 10
      t.string :date_format, default: '%B %d, %Y'

      t.timestamps
    end
  end
end
