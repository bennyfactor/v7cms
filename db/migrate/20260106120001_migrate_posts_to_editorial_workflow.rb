class MigratePostsToEditorialWorkflow < ActiveRecord::Migration[7.0]
  # Define minimal models for migration to avoid dependencies on app models
  class Post < ActiveRecord::Base
    self.table_name = 'posts'
  end

  class ContentVersion < ActiveRecord::Base
    self.table_name = 'content_versions'
  end

  def up
    # For each post that has published: true, create a published version
    # and set the appropriate status and published_version_id
    execute <<-SQL
      UPDATE posts SET status = 'published' WHERE published = 1
    SQL

    # Create ContentVersions for published posts
    Post.where(published: true).find_each do |post|
      # Get the current max version number for this post
      max_version = ContentVersion.where(
        versionable_type: 'Post',
        versionable_id: post.id
      ).maximum(:version_number) || 0

      version = ContentVersion.create!(
        versionable_type: 'Post',
        versionable_id: post.id,
        version_number: max_version + 1,
        version_type: 'workflow',
        workflow_state: 'published',
        title: post.title,
        content: post.content,
        metadata: { slug: post.slug, comments_enabled: post.comments_enabled }.to_json,
        expires_at: nil
      )
      post.update_column(:published_version_id, version.id)
    end
  end

  def down
    # Revert status based on published_version_id
    execute <<-SQL
      UPDATE posts SET published = 1 WHERE published_version_id IS NOT NULL
    SQL
    execute <<-SQL
      UPDATE posts SET published = 0 WHERE published_version_id IS NULL
    SQL
  end
end
