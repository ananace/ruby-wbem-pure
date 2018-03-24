require 'net/http'
require 'net/http/digest_auth'
require 'nokogiri'
require 'uri'

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
      data = build_soap('xmlns:wsmid' => 'http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd') do |xml|
        xml['wsmid'].Identify {}
      end

      post(data)
    end

    def host
      @url.host
    end

    def port
      @url.port
    end

    private

    def build_soap(namespaces = {}, &block)
      Nokogiri::XML::Builder.new do |xml|
        xml['s'].Envelope(namespaces.merge('xmlns:s' => 'http://www.w3.org/2003/05/soap-envelope')) {
          xml['s'].Header {}
          xml['s'].Body {
            yield xml
          }
        }
      end
    end

    def post(xml)
      logger.info xml.inspect
      xml = xml.to_xml(indent: 0) unless xml.is_a? String

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
