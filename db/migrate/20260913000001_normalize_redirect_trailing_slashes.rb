class NormalizeRedirectTrailingSlashes < ActiveRecord::Migration[7.0]
  # Redirect#short_path is now stored without a trailing slash. Canonicalize
  # existing rows; when both "/foo" and "/foo/" exist, keep the canonical one.
  def up
    rows = select_all("SELECT id, short_path FROM redirects WHERE short_path LIKE '%/' AND short_path <> '/'")
    rows.each do |row|
      canonical = row['short_path'].sub(%r{/+\z}, '')
      twin = select_value('SELECT id FROM redirects WHERE short_path = ?'.sub('?', quote(canonical)))
      if twin
        say "Removing redirect #{row['short_path']} (id #{row['id']}): canonical #{canonical} already exists"
        execute "DELETE FROM redirects WHERE id = #{row['id'].to_i}"
      else
        execute "UPDATE redirects SET short_path = #{quote(canonical)} WHERE id = #{row['id'].to_i}"
      end
    end
  end

  def down
    # Trailing slashes are not restored; the canonical form serves both.
  end
end
