module ActionController
  class RedirectBackError < ActionControllerError #:nodoc:
    DEFAULT_MESSAGE = 'No HTTP_REFERER was set in the request to this action, so redirect_to :back could not be called successfully. If this is a test, make sure to specify request.env["HTTP_REFERER"].'

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end
  
  module Redirector

    # Redirects the browser to the target specified in +options+. This parameter can take one of three forms:
    #
    # * <tt>Hash</tt> - The URL will be generated by calling url_for with the +options+.
    # * <tt>Record</tt> - The URL will be generated by calling url_for with the +options+, which will reference a named URL for that record.
    # * <tt>String</tt> starting with <tt>protocol://</tt> (like <tt>http://</tt>) - Is passed straight through as the target for redirection.
    # * <tt>String</tt> not containing a protocol - The current protocol and host is prepended to the string.
    # * <tt>:back</tt> - Back to the page that issued the request. Useful for forms that are triggered from multiple places.
    #   Short-hand for <tt>redirect_to(request.env["HTTP_REFERER"])</tt>
    #
    # Examples:
    #   redirect_to :action => "show", :id => 5
    #   redirect_to post
    #   redirect_to "http://www.rubyonrails.org"
    #   redirect_to "/images/screenshot.jpg"
    #   redirect_to articles_url
    #   redirect_to :back
    #
    # The redirection happens as a "302 Moved" header unless otherwise specified.
    #
    # Examples:
    #   redirect_to post_url(@post), :status=>:found
    #   redirect_to :action=>'atom', :status=>:moved_permanently
    #   redirect_to post_url(@post), :status=>301
    #   redirect_to :action=>'atom', :status=>302
    #
    # When using <tt>redirect_to :back</tt>, if there is no referrer,
    # RedirectBackError will be raised. You may specify some fallback
    # behavior for this case by rescuing RedirectBackError.
    def redirect_to(options = {}, response_status = {}) #:doc:
      raise ActionControllerError.new("Cannot redirect to nil!") if options.nil?

      if options.is_a?(Hash) && options[:status]
        status = options.delete(:status)
      elsif response_status[:status]
        status = response_status[:status]
      else
        status = 302
      end

      case options
        # The scheme name consist of a letter followed by any combination of
        # letters, digits, and the plus ("+"), period ("."), or hyphen ("-")
        # characters; and is terminated by a colon (":").
        when %r{^\w[\w\d+.-]*:.*}
          redirect_to_full_url(options, status)
        when String
          redirect_to_full_url(request.protocol + request.host_with_port + options, status)
        when :back
          if referer = request.headers["Referer"]
            redirect_to(referer, :status=>status)
          else
            raise RedirectBackError
          end
        else
          redirect_to_full_url(url_for(options), status)
      end
    end

    def redirect_to_full_url(url, status)
      raise DoubleRenderError if performed?
      logger.info("Redirected to #{url}") if logger && logger.info?
      response.status = interpret_status(status)
      response.location = url.gsub(/[\r\n]/, '')
      response.body = "<html><body>You are being <a href=\"#{CGI.escapeHTML(url)}\">redirected</a>.</body></html>"      
      @performed_redirect = true
    end
    
    # Clears the redirected results from the headers, resets the status to 200 and returns
    # the URL that was used to redirect or nil if there was no redirected URL
    # Note that +redirect_to+ will change the body of the response to indicate a redirection.
    # The response body is not reset here, see +erase_render_results+
    def erase_redirect_results #:nodoc:
      @performed_redirect = false
      response.status = DEFAULT_RENDER_STATUS_CODE
      response.headers.delete('Location')
    end
  end
end