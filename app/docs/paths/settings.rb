# frozen_string_literal: true

require 'swagger/blocks'

class SettingsPaths
  include Swagger::Blocks

  swagger_path '/api/settings' do
    operation :get do
      key :summary, 'Get settings'
      key :description, 'Returns current site settings'
      key :operationId, 'getSettings'
      key :tags, ['Settings']

      response 200 do
        key :description, 'Site settings'
        content 'application/json' do
          schema do
            key :'$ref', :SettingsResponse
          end
        end
      end
    end

    operation :put do
      key :summary, 'Update settings'
      key :description, 'Update site settings. Requires authentication.'
      key :operationId, 'updateSettings'
      key :tags, ['Settings']

      request_body do
        key :required, true
        content 'application/json' do
          schema do
            key :'$ref', :SettingsInput
          end
        end
      end

      response 200 do
        key :description, 'Settings updated successfully'
        content 'application/json' do
          schema do
            key :'$ref', :SettingsResponse
          end
        end
      end
      response 401 do
        key :description, 'Unauthorized'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
      response 422 do
        key :description, 'Validation error'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
  end

  swagger_path '/api/settings/reset' do
    operation :post do
      key :summary, 'Reset settings'
      key :description, 'Reset all settings to default values. Requires authentication.'
      key :operationId, 'resetSettings'
      key :tags, ['Settings']

      response 200 do
        key :description, 'Settings reset to defaults'
        content 'application/json' do
          schema do
            key :'$ref', :SettingsResponse
          end
        end
      end
      response 401 do
        key :description, 'Unauthorized'
        content 'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
  end
end
