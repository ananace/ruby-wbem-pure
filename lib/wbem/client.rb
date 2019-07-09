# frozen_string_literal: true

require 'net/http'
require 'net/http/digest_auth'
require 'securerandom'
require 'wbem'

module Wbem
  class Client
    def initialize(url_, opts = {})
      @url = url_
      @url = URI.parse @url unless @url.is_a? URI

      @url.user = opts[:username] if opts[:username]
      @url.password = opts[:password] if opts[:password]

      @auth_method = opts[:auth_method] || :basic

      @connection = Net::HTTP.new @url.host, @url.port
    end

    def identify
      Wbem::Object.new self, 'Identity', post_data(build_soap(:identify))
    end

    def enumerate(object, selectors = {})
      resp = post_data(build_soap(:enumerate, resource_uri: object, selectors: selectors))

      data = []

      loop do
        ctx = resp.at_xpath("//*[local-name()='EnumerationContext']").text
        resp = post_data(build_soap(:pull, context: ctx, resource_uri: object, selectors: selectors))

        data << resp

        break if resp.xpath("//*[local-name()='EndOfSequence']").any? \
              || resp.xpath("//*[local-name()='EnumerationContext']").none?
      end

      data.select { |d| d.at_xpath("//*[local-name()='Items']").children.any? }
          .map { |d| Wbem::Object.new self, object, d.at_xpath("//*[local-name()='Items']").child }
    end

    def get(object, selectors = {})
      obj = post_data(build_soap(:get, resource_uri: object, selectors: selectors))
      Wbem::Object.new self, object, obj
    end

    def invoke(object, method, selectors = {})
      obj = post_data(
        build_soap(:invoke, resource_uri: object, command: method, selectors: selectors) do |xml|
          yield xml if block_given?
        end
      )
      Wbem::Object.new self, object, obj
    end

    def host
      @url.host
    end

    def port
      @url.port
    end

    private

    def build_soap(method, **options)
      method = method.to_s.downcase.to_sym
      namespaces = options[:namespaces] || {}
      namespaces['xmlns'] = 'http://www.w3.org/2003/05/soap-envelope'

      if method != :identify
        namespaces.merge!(
          'xmlns:a' => 'http://schemas.xmlsoap.org/ws/2004/08/addressing',
          'xmlns:w' => 'http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd',
          'xmlns:p' => 'http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd'
        )

        namespaces['xmlns:n'] = 'http://schemas.xmlsoap.org/ws/2004/09/enumeration' \
          if %i[enumerate pull].include? method

        namespaces['xmlns:b'] = 'http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd' \
          if method == :enumerate
      end

      action_ns = case method
                  when :create, :delete, :get, :put
                    'http://schemas.xmlsoap.org/ws/2004/09/transfer'
                  when :subscribe, :unsubscribe
                    'http://schemas.xmlsoap.org/ws/2004/08/eventing'
                  when :enumerate, :pull
                    'http://schemas.xmlsoap.org/ws/2004/09/enumeration'
                  when :invoke
                    options[:resource_uri]
                  end
      invoke_command = options[:command]

      Nokogiri::XML::Builder.new do |xml|
        xml.Envelope(namespaces) do

          xml.Header do
            if method != :identify
              xml['a'].Action("#{action_ns}/#{invoke_command || method.to_s.capitalize}")
              xml['a'].To(@url.path)
              xml['w'].ResourceURI(options[:resource_uri])
              xml['a'].MessageID("uuid:#{SecureRandom.uuid}")
              xml['a'].ReplyTo do
                xml['a'].Address('http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous')
              end

              xml['w'].OperationTimeout('PT60S')
              if options[:selectors]&.any?
                xml['w'].SelectorSet do
                  options[:selectors].each do |k, v|
                    xml['w'].Selector(v.to_s, 'Name' => k.to_s)
                  end
                end
              end

              if method == :subscribe && (options[:username] && options[:password])
                xml['t'].IssuedTokens('xmlns:t' => 'http://schemas.xmlsoap.org/ws/2005/02/trust',
                                      'xmlns:se' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd') do
                  xml['t'].RequestSecurityTokenResponse do
                    xml['t'].TokenType('http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#UsernameToken')
                    xml['t'].RequestedSecurityToken do
                      xml['se'].UsernameToken do
                        xml['se'].Username(options[:username])
                        xml['se'].Password(options[:password], 'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd#PasswordText')
                      end
                    end
                  end
                end
              end
            end
          end

          xml.Body do
            if method == :identify
              xml.Identify('xmlns' => 'http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd')
            elsif method == :unsubscribe
              xml['e'].Unsubscribe 'xmlns:e' => 'http://schemas.xmlsoap.org/ws/2004/08/eventing'
            elsif method == :subscribe
              xml['e'].Subscribe('xmlns:e' => 'http://schemas.xmlsoap.org/ws/2004/08/eventing') do
                delivery_scheme = case options[:delivery_mode]
                                  when :push
                                    'http://schemas.xmlsoap.org/ws/2004/08/eventing/DeliveryModes/Push'
                                  when :push_with_ack
                                    'http://schemas.dmtf.org/wbem/wsman/1/wsman/PushWithAck'
                                  end

                xml['e'].Delivery('Mode' => delivery_scheme) do
                  xml['e'].NotifyTo do
                    xml['a'].Address(options[:notify_url])
                    if options[:opaque]
                      xml['a'].ReferenceParameters do
                        xml['m'].arg(options[:opaque], 'xmlns:m' => 'http://x.com')
                      end
                    end
                  end

                  xml['w'].Auth('Profile' => 'http://schemas.dmtf.org/wbem/wsman/1/wsman/secprofile/http/digest') \
                    if options[:username] && options[:password]
                end
              end
            elsif method == :invoke
              xml.send "#{invoke_command}_INPUT".to_sym, 'xmlns' => options[:resource_uri] do
                yield xml if block_given?
              end
            elsif %i[enumerate pull].include? method
              xml['n'].send(method.to_s.capitalize.to_sym) do
                if method == :enumerate
                  xml['w'].OptimizeEnumeration
                  xml['w'].MaxElements(32_000)
                end

                xml['n'].EnumerationContext(options[:context]) if method == :pull

                yield xml if block_given?
              end
            elsif block_given?
              yield xml
            end
          end
        end
      end
    end

    def post_data(xml)
      xml = '<?xml version="1.0"?>' + xml.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION).strip unless xml.is_a? String
      logger.debug xml.inspect

      req = Net::HTTP::Post.new @url.request_uri
      req.content_type = 'application/xml; charset=utf-8'
      req.body = xml if @auth_method == :basic
      print_http(req)

      resp = connection.request req
      print_http(resp)
      if resp.is_a? Net::HTTPUnauthorized
        @auth_method = :digest if resp['www-authenticate'].start_with? 'Digest'

        auth = digest_auth.auth_header @url, resp['www-authenticate'], 'POST'

        req = Net::HTTP::Post.new @url.request_uri
        req.content_type = 'application/xml; charset=utf-8'
        req.body = xml
        req.add_field 'Authorization', auth

        print_http(req)
        resp = @connection.request req
        print_http(resp)
      end

      if resp # .is_a? Net::HTTPOK
        logger.debug resp.body

        return Nokogiri::XML(resp.body)
      end

      nil # TODO: Exceptions
    end

    def digest_auth
      @digest_auth ||= begin
        auth = Net::HTTP::DigestAuth.new
        auth.next_nonce
        auth
      end
    end

    def message_id
      @message_id ||= 0
      @message_id += 1
    end

    def print_http(http)
      dir = http.is_a?(Net::HTTPRequest) ? '>' : '<'

      if http.is_a? Net::HTTPRequest
        logger.debug "#{dir} #{http.method} #{http.path}"
      else
        logger.debug "#{dir} #{http.code} #{http.message}"
      end
      http.each_header do |k, v|
        logger.debug "#{dir} #{k}: #{v}"
      end
      logger.debug dir
    end

    def logger
      @logger ||= Logging.logger[self]
    end

    attr_reader :connection
  end
end
