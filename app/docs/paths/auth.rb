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

  swagger_path '/api/auth/csrf' do
    operation :get do
      key :summary, 'Get CSRF token for login'
      key :description, 'Returns the session authenticity token required to start an OAuth login. Not cacheable.'
      key :operationId, 'getLoginCsrfToken'
      key :tags, ['Auth']

      response 200 do
        key :description, 'Authenticity token for the current session'
        content 'application/json' do
          schema do
            key :type, :object
            property :token do
              key :type, :string
            end
          end
        end
      end
    end
  end

  swagger_path '/auth/google_oauth2' do
    operation :post do
      key :summary, 'Login with Google'
      key :description, 'Initiate Google OAuth2 login flow with a form POST carrying authenticity_token from /api/auth/csrf. Redirects to Google.'
      key :operationId, 'loginGoogle'
      key :tags, ['Auth']

      request_body do
        key :required, true
        content 'application/x-www-form-urlencoded' do
          schema do
            key :type, :object
            property :authenticity_token do
              key :type, :string
            end
          end
        end
      end

      response 302 do
        key :description, 'Redirect to Google OAuth2'
      end
    end
  end

  swagger_path '/auth/github' do
    operation :post do
      key :summary, 'Login with GitHub'
      key :description, 'Initiate GitHub OAuth login flow with a form POST carrying authenticity_token from /api/auth/csrf. Redirects to GitHub.'
      key :operationId, 'loginGithub'
      key :tags, ['Auth']

      request_body do
        key :required, true
        content 'application/x-www-form-urlencoded' do
          schema do
            key :type, :object
            property :authenticity_token do
              key :type, :string
            end
          end
        end
      end

      response 302 do
        key :description, 'Redirect to GitHub OAuth'
      end
    end
  end
end
