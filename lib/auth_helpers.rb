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
    halt 401 unless encoded_token = env[MOBILE_X_HEADER] # TODO better 'auth token missing' error code?
    mobile_token = Base64.urlsafe_decode64(encoded_token)
    # EXAMPLE halt 401 unless Account.find_by_mobile_token(mobile_token)
    true
  end

  # Implementation example
  def internal_api_key_check
    true
  end

end

Sinatra::Helpers.send(:include, AuthHelpers)
