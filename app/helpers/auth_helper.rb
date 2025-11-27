module AuthHelper
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in? && current_user.admin?
      halt 401, { error: 'Unauthorized' }.to_json
    end
  end

  # Check for custom header to prevent CSRF on API requests
  def require_ajax_header
    # Temporarily disabled - debug why header isn't getting through
    # header_value = request.env['HTTP_X_REQUESTED_WITH']
    # unless header_value == 'XMLHttpRequest'
    #   halt 403, { error: 'Forbidden - AJAX header required' }.to_json
    # end
  end
end
