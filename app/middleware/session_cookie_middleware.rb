require 'rack/utils'

# Handles flash-based authentication, performed by passing the DC session from
# JavaScript to the Flash object.
#
# Also, prevents session cookies from ever being set in a non-SSL request
# (currently, a bug in Rails 2.3.9)
class SessionCookieMiddleware

  # Detect Flash's User-Agent header.
  FLASH_MATCHER = /^(Adobe|Shockwave) Flash/

  def initialize(app, session_key = '_session_id')
    @app = app
    @session_key = session_key
  end

  # If a given request is a Flash request, take the "session_key" parameter,
  # and serialize it into the HTTP_COOKIE header.
  #
  # After the app has been called, if the request is not secure, remove the
  # session cookie.
  def call(env)

    # Flash bit.
    if env['HTTP_USER_AGENT'] =~ FLASH_MATCHER
      req = Rack::Request.new(env)
      if req.params['session_key']
        base64 = req.params['session_key'].gsub(' ', '%2B')
        env['HTTP_COOKIE'] = "#{@session_key}=#{base64}".freeze
      end
    end

    # Call the application.
    response = @app.call(env)

    # Secure session bit.
    unless env['HTTPS'] == 'on' || env['HTTP_X_FORWARDED_PROTO'] == 'https'
      cookies = response[1]['Set-Cookie']
      cookies.pop if cookies && (cookies.last[0...@session_key.length] == @session_key)
    end

    response
  end
end