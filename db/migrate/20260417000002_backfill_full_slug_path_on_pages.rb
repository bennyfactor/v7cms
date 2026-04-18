class BackfillFullSlugPathOnPages < ActiveRecord::Migration[7.0]
  def up
    # Backfill top-level pages (no parent)
    execute "UPDATE pages SET full_slug_path = slug WHERE parent_id IS NULL AND full_slug_path IS NULL"

    # Iteratively backfill nested pages level by level
    # Keep going until no more NULL full_slug_path values remain
    update_sql = <<-SQL
      UPDATE pages
      SET full_slug_path = (
        SELECT p.full_slug_path || '/' || pages.slug
        FROM pages p
        WHERE p.id = pages.parent_id AND p.full_slug_path IS NOT NULL
      )
      WHERE parent_id IS NOT NULL AND full_slug_path IS NULL
      AND parent_id IN (SELECT id FROM pages WHERE full_slug_path IS NOT NULL)
    SQL

    loop do
      remaining_before = connection.select_value("SELECT COUNT(*) FROM pages WHERE full_slug_path IS NULL").to_i
      break if remaining_before == 0

      execute(update_sql)

      remaining_after = connection.select_value("SELECT COUNT(*) FROM pages WHERE full_slug_path IS NULL").to_i
      break if remaining_after == 0 || remaining_after == remaining_before
    end

    change_column_null :pages, :full_slug_path, false
  end

  def down
    change_column_null :pages, :full_slug_path, true
  end
end
