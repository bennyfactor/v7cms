# frozen_string_literal: true

require 'spec_helper'

# The renderer specs cover ThemeStyleHelper through the static templates;
# these cover the dynamic layout, so a regression in the helper registration
# or the preview override path cannot slip through.
RSpec.describe 'Dynamic layout theme styles' do
  before do
    Setting.instance.update_columns(site_tagline: 'A test tagline')
  end

  it 'renders the persisted minimal header and footer styles' do
    Theme.instance.update_columns(header_style: 'minimal', footer_style: 'minimal')

    get '/'

    expect(last_response.body).to include('<header class="bg-white border-b">')
    expect(last_response.body).to include('px-4 py-3')
    expect(last_response.body).not_to include('A test tagline')
    expect(last_response.body).to include('<footer class="bg-white border-t mt-auto">')
    expect(last_response.body).to include('py-3 text-center text-gray-600 text-xs')
  end

  it 'renders the persisted centered footer style' do
    Theme.instance.update_columns(footer_style: 'centered')

    get '/'

    expect(last_response.body).to include('py-4 text-center text-gray-600 text-sm')
  end

  it 'renders the default footer style' do
    Theme.instance.update_columns(footer_style: 'default')

    get '/'

    expect(last_response.body).to include('py-6 text-center text-gray-600 text-sm')
  end

  it 'renders the persisted prominent header style' do
    Theme.instance.update_columns(header_style: 'prominent')

    get '/'

    expect(last_response.body).to include('<header class="bg-white shadow-lg">')
    expect(last_response.body).to include('text-3xl')
  end

  it 'honors a preview override from params' do
    Theme.instance.update_columns(header_style: 'default')

    get '/', theme_preview: '1', header_style: 'prominent'

    expect(last_response.body).to include('<header class="bg-white shadow-lg">')
  end
end
