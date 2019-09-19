# frozen_string_literal: true

require 'rails-reverse-proxy'

module Quilt
  module ReactRenderable
    include ReverseProxy::Controller

    def render_react
      raise DoNotIntegrationTestError if Rails.env.test?

      if defined? ShopifySecurityBase
        ShopifySecurityBase::HTTPHostRestriction.whitelist([Quilt.configuration.react_server_host]) do
          proxy
        end
      else
        proxy
      end
    end

    private

    def proxy
      url = "#{Quilt.configuration.react_server_protocol}://#{Quilt.configuration.react_server_host}"
      Quilt::Logger.log("[ReactRenderable] proxying to React server at #{url}")

      begin
        reverse_proxy(url, headers: { 'X-CSRF-Token': form_authenticity_token }) do |callbacks|
          callbacks.on_response do |status_code, response|
            Quilt::Logger.log("[ReactRenderable] #{url} returned #{status_code}")
            puts "\n\n********************~~~Headers: #{response.to_hash.inspect}"
          end
        end
      rescue Errno::ECONNREFUSED
        raise ReactServerNoResponseError, url
      end
    end

    class ReactServerNoResponseError < StandardError
      def initialize(url)
        # rubocop:disable LineLength
        super "Errno::ECONNREFUSED: Waiting for React server to boot up. If this error presists verify that @shopify/react-server is configured on #{url}"
      end
    end

    class DoNotIntegrationTestError < StandardError
      def initialize
        super "Do not try to use Rails integration tests on your quilt_rails app. Instead use Jest and @shopify/react-testing to test your React application directly."
      end
    end
  end
end
