module AuthHelpers

  MOBILE_X_HEADER   = 'HTTP_X_MOBILE_TOKEN'
  INTERNAL_X_HEADER = 'HTTP_X_INTERNAL_API_KEY'

  # Implementation example
  def pre_dispatch_hook
    if service.extra[:mobile]
      mobile_auth_check
    elsif service.extra[:internal]
      internal_api_key_check
    elsif !service.auth_required
      return
    else
      halt 403 # protect by default
    end
  end

  # Implementation example
  def mobile_auth_check
    true
  end

  # Implementation example
  def internal_api_key_check
    true
  end

end

Sinatra::Helpers.send(:include, AuthHelpers)
