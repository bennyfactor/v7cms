class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
    add_index :users, :admin

    # Backfill: Set admin=true for users whose email is in ADMIN_EMAILS
    reversible do |dir|
      dir.up do
        admin_emails = ENV['ADMIN_EMAILS']&.split(',')&.map(&:strip) || []
        admin_emails.each do |email|
          execute "UPDATE users SET admin = true WHERE email = '#{sanitize_sql(email)}'"
        end
      end
    end
  end

  private

  def sanitize_sql(value)
    ActiveRecord::Base.connection.quote_string(value)
  end
end
