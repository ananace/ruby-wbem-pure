require 'net/http'
require 'net/http/digest_auth'
require 'nokogiri'
require 'securerandom'
require 'uri'
require 'wbem/object'

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


    def enumerate(object, options = {})
      resp = post_data(build_soap(:enumerate, options.merge(resource_uri: object)))

      data = []

      begin
        ctx = resp.at_xpath("//*[local-name()='EnumerationContext']").text
        resp = post_data(build_soap(:pull, options.merge(context: ctx, resource_uri: object)))

        data << resp
      end while resp.xpath("//*[local-name()='EnumerationContext']").any?

      data.select do |d|
        d.at_xpath("//*[local-name()='Items']").children.any?
      end.map do |d|
        Wbem::Object.new self, object, d.at_xpath("//*[local-name()='Items']").child
      end
    end

    def get(object, options = {})
      obj = post_data(build_soap(:get, options.merge(resource_uri: object)))
      Wbem::Object.new self, object, obj 
    end

    def host
      @url.host
    end

    def port
      @url.port
    end

    private

    def build_soap(method, options = {})
      method = method.to_s.downcase.to_sym
      namespaces = options[:namespaces] || {}
      namespaces.merge!(
        'xmlns' => 'http://www.w3.org/2003/05/soap-envelope',
      )

      if method != :identify
        namespaces.merge!(
          'xmlns:a' => 'http://schemas.xmlsoap.org/ws/2004/08/addressing',
          'xmlns:w' => 'http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd',
          'xmlns:p' => 'http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd'
        )

        if method == :enumerate || method == :pull
          namespaces.merge!(
            'xmlns:n' => 'http://schemas.xmlsoap.org/ws/2004/09/enumeration'
          )
        end

        namespaces.merge!(
          'xmlns:b' => 'http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd'
        ) if method == :enumerate
      end

      actionNS = case method
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
        xml.Envelope(namespaces) {
          xml.Header {
            if method != :identify
              xml['a'].Action("#{actionNS}/#{invoke_command || (method.to_s.capitalize)}")
              xml['a'].To(@url.path)
              xml['w'].ResourceURI(options[:resource_uri])
              xml['a'].MessageID("uuid:#{SecureRandom.uuid}")
              xml['a'].ReplyTo {
                xml['a'].Address('http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous')
              }
              xml['w'].OperationTimeout('PT60S')
              xml['w'].SelectorSet {
                options[:selectors].each do |k,v|
                  xml['w'].Selector(v.to_s, 'Name' => k.to_s)
                end
              } if options[:selectors] && options[:selectors].any?
              xml['t'].IssuedTokens('xmlns:t' => 'http://schemas.xmlsoap.org/ws/2005/02/trust', 'xmlns:se' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd') {
                xml['t'].RequestSecurityTokenResponse {
                  xml['t'].TokenType('http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#UsernameToken')
                  xml['t'].RequestedSecurityToken {
                    xml['se'].UsernameToken {
                      xml['se'].Username(options[:username])
                      xml['se'].Password(options[:password], 'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd#PasswordText')
                    }
                  }
                }
              } if method == :subscribe && (options[:username] && options[:password])
            end
          }
          xml.Body {
            if method == :identify
              xml.Identify('xmlns' => 'http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd')
            elsif method == :unsubscribe
              xml['e'].Unsubscribe 'xmlns:e' => 'http://schemas.xmlsoap.org/ws/2004/08/eventing'
            elsif method == :subscribe
              xml['e'].Subscribe('xmlns:e' => 'http://schemas.xmlsoap.org/ws/2004/08/eventing') {
                delivery_scheme = case options[:delivery_mode]
                                  when :push
                                    'http://schemas.xmlsoap.org/ws/2004/08/eventing/DeliveryModes/Push'
                                  when :push_with_ack
                                    'http://schemas.dmtf.org/wbem/wsman/1/wsman/PushWithAck'
                                  end
                xml['e'].Delivery('Mode' => delivery_scheme) {
                  xml['e'].NotifyTo {
                    xml['a'].Address(options[:notify_url])
                    xml['a'].ReferenceParameters {
                      xml['m'].arg(options[:opaque], 'xmlns:m' => 'http://x.com')
                    } if options[:opaque]
                  }

                  xml['w'].Auth('Profile' => 'http://schemas.dmtf.org/wbem/wsman/1/wsman/secprofile/http/digest') \
                    if options[:username] && options[:password]
                }
              }
            elsif method == :invoke
              xml.send "#{invoke_command}_INPUT".to_sym, 'xmlns' => options[:resource_uri] {
                yield xml if block_given?
              }
            elsif method == :enumerate || method == :pull
              xml['n'].send(method.to_s.capitalize.to_sym) {
                # xml['w'].MaxElements(32000)

                # xml['w'].OptimizeEnumeration if method == :enumerate
                xml['n'].EnumerationContext(options[:context]) if method == :pull

                yield xml if block_given?
              }
            else
              yield xml if block_given?
            end
          }
        }
      end
    end

    def post_data(xml)
      xml = '<?xml version="1.0"?>' + xml.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION).strip unless xml.is_a? String
      logger.debug xml.inspect

      req = Net::HTTP::Post.new @url.request_uri
      req.content_type = 'application/xml; charset=utf-8'
      req.body = xml
      print_http(req)

      resp = connection.request req
      print_http(resp)
      if resp.is_a? Net::HTTPUnauthorized
        auth = digest_auth.auth_header @url, resp['www-authenticate'], 'POST'

        req = Net::HTTP::Post.new @url.request_uri
        req.content_type = 'application/xml; charset=utf-8'
        req.body = xml
        req.add_field 'Authorization', auth

        print_http(req)
        resp = @connection.request req
        print_http(resp)
      end

      if resp #.is_a? Net::HTTPOK
        logger.debug resp.body

        return Nokogiri::XML(resp.body)
      else
        nil # TODO: Exceptions
      end
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
      http.each_header do |k,v|
        logger.debug "#{dir} #{k}: #{v}"
      end
      logger.debug "#{dir}"
    end

    def logger
      Wbem.logger
    end
      
    attr_reader :connection
  end
end
