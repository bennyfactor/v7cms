# frozen_string_literal: true

require 'swagger/blocks'

class AuthPaths
  include Swagger::Blocks

  swagger_path '/api/auth/me' do
    operation :get do
      key :summary, 'Get current user'
      key :description, 'Returns the currently authenticated user and login status'
      key :operationId, 'getCurrentUser'
      key :tags, ['Auth']

      response 200 do
        key :description, 'Authentication status and user info'
        content 'application/json' do
          schema do
            key :'$ref', :AuthStatus
          end
        end
      end
    end
  end

  swagger_path '/api/auth/logout' do
    operation :post do
      key :summary, 'Logout'
      key :description, 'End the current session'
      key :operationId, 'logout'
      key :tags, ['Auth']

      response 200 do
        key :description, 'Logged out successfully'
        content 'application/json' do
          schema do
            key :'$ref', :Success
          end
        end
      end
    end
  end

  swagger_path '/auth/google_oauth2' do
    operation :get do
      key :summary, 'Login with Google'
      key :description, 'Initiate Google OAuth2 login flow. Redirects to Google.'
      key :operationId, 'loginGoogle'
      key :tags, ['Auth']

      response 302 do
        key :description, 'Redirect to Google OAuth2'
      end
    end
  end

  swagger_path '/auth/github' do
    operation :get do
      key :summary, 'Login with GitHub'
      key :description, 'Initiate GitHub OAuth login flow. Redirects to GitHub.'
      key :operationId, 'loginGithub'
      key :tags, ['Auth']

      response 302 do
        key :description, 'Redirect to GitHub OAuth'
      end
    end
  end
end
