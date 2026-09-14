require 'spec_helper'

migration_file = Dir[File.expand_path('../../db/migrate/*_normalize_redirect_trailing_slashes.rb', __dir__)].first
require migration_file

RSpec.describe NormalizeRedirectTrailingSlashes do
  def legacy(short_path, target)
    row = Redirect.create!(short_path: "/tmp-#{SecureRandom.hex(3)}", target_path: target)
    row.update_column(:short_path, short_path)
    row
  end

  def run_up
    described_class.new.tap { |m| m.instance_variable_set(:@connection, ActiveRecord::Base.connection) }.up
  end

  it 'strips trailing slashes from rows without a canonical twin' do
    row = legacy('/old-wiki/', '/pages/wiki')
    run_up
    expect(row.reload.short_path).to eq('/old-wiki')
  end

  it 'removes a trailing-slash row when its canonical twin exists, keeping the canonical target' do
    Redirect.create!(short_path: '/blog2', target_path: '/pages/blog')
    dup = legacy('/blog2/', '/pages/other')
    run_up
    expect(Redirect.where(id: dup.id)).not_to exist
    expect(Redirect.find_by(short_path: '/blog2').target_path).to eq('/pages/blog')
  end

  it 'leaves canonical rows untouched' do
    Redirect.create!(short_path: '/fine', target_path: '/pages/fine')
    expect { run_up }.not_to(change { Redirect.find_by(short_path: '/fine').updated_at })
  end

  it 'keeps the shortest variant when several legacy variants exist without a canonical twin' do
    longer = legacy('/multi//', '/pages/longer')
    shorter = legacy('/multi/', '/pages/shorter')
    run_up
    expect(Redirect.where(id: longer.id)).not_to exist
    expect(shorter.reload.short_path).to eq('/multi')
    expect(shorter.target_path).to eq('/pages/shorter')
  end

  it 'is irreversible' do
    expect { described_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
