require 'base64'

module OAuth2
  module Strategy
    # The Client Credentials Strategy
    #
    # @see http://tools.ietf.org/html/draft-ietf-oauth-v2-15#section-4.4
    class ClientCredentials < Base
      # Not used for this strategy
      #
      # @raise [NotImplementedError]
      def authorize_url
        raise(NotImplementedError, 'The authorization endpoint is not used in this strategy')
      end

      # Retrieve an access token given the specified client.
      #
      # @param [Hash] params additional params
      # @param [Hash] opts options
      # @option opts [String] :header_format ('Basic') the string format to use for the Authorization header
      def get_token(params = {}, opts = {})
        request_body = opts.delete('auth_scheme') == 'request_body'
        params['grant_type'] = 'client_credentials'
        params.merge!(request_body ? client_params : {:headers => {'Authorization' => authorization(client_params['client_id'], client_params['client_secret'], opts.delete(:header_format) || 'Basic')}})
        @client.get_token(params, opts.merge('refresh_token' => nil))
      end

      # Returns the Authorization header value for Authentication
      #
      # @param [String] The client ID
      # @param [String] the client secret
      # @param [String] the authorization header string format
      def authorization(client_id, client_secret, header_format)
        header_format + ' ' + Base64.encode64(client_id + ':' + client_secret).delete("\n")
      end
    end
  end
end
