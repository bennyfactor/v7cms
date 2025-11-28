# frozen_string_literal: true

require 'swagger/blocks'

class FeedPaths
  include Swagger::Blocks

  swagger_path '/feed/rss' do
    operation :get do
      key :summary, 'RSS feed'
      key :description, 'Returns RSS 2.0 feed of published posts'
      key :operationId, 'getRssFeed'
      key :tags, ['Feeds']

      response 200 do
        key :description, 'RSS feed'
        content 'application/rss+xml' do
          schema do
            key :type, :string
            key :format, :xml
          end
        end
      end
    end
  end

  swagger_path '/feed/atom' do
    operation :get do
      key :summary, 'Atom feed'
      key :description, 'Returns Atom 1.0 feed of published posts'
      key :operationId, 'getAtomFeed'
      key :tags, ['Feeds']

      response 200 do
        key :description, 'Atom feed'
        content 'application/atom+xml' do
          schema do
            key :type, :string
            key :format, :xml
          end
        end
      end
    end
  end
end
