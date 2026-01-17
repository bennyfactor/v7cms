class MigratePagesToEditorialWorkflow < ActiveRecord::Migration[7.0]
  # Define minimal models for migration to avoid dependencies on app models
  class Page < ActiveRecord::Base
    self.table_name = 'pages'
  end

  class ContentVersion < ActiveRecord::Base
    self.table_name = 'content_versions'
  end

  def up
    # For each page that has published: true, create a published version
    # and set the appropriate status and published_version_id
    execute <<-SQL
      UPDATE pages SET status = 'published' WHERE published = 1
    SQL

    # Create ContentVersions for published pages
    Page.where(published: true).find_each do |page|
      # Get the current max version number for this page
      max_version = ContentVersion.where(
        versionable_type: 'Page',
        versionable_id: page.id
      ).maximum(:version_number) || 0

      version = ContentVersion.create!(
        versionable_type: 'Page',
        versionable_id: page.id,
        version_number: max_version + 1,
        version_type: 'workflow',
        workflow_state: 'published',
        title: page.title,
        content: page.content,
        metadata: {
          slug: page.slug,
          page_type: page.page_type,
          content_source: page.content_source,
          items_limit: page.items_limit,
          position: page.position,
          parent_id: page.parent_id,
          hero_image_url: page.hero_image_url
        }.to_json,
        expires_at: nil
      )
      page.update_column(:published_version_id, version.id)
    end
  end

  def down
    # Revert status based on published_version_id
    execute <<-SQL
      UPDATE pages SET published = 1 WHERE published_version_id IS NOT NULL
    SQL
    execute <<-SQL
      UPDATE pages SET published = 0 WHERE published_version_id IS NULL
    SQL
  end
end
