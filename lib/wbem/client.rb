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
      xml = build_soap('xmlns:wsmid' => 'http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd') do |xml|
        xml['wsmid'].Identify {}
      end.to_xml

      resp = post(xml)

      puts resp
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
      puts "Sending:\n#{xml}\n"

      req = Net::HTTP::Post.new @url.request_uri
      req.content_type = 'application/xml; charset=utf-8'
      req.body = xml
      resp = connection.request req

      puts resp.inspect, resp.to_hash, resp.body, ''
      if resp.is_a? Net::HTTPUnauthorized
        auth = digest_auth.auth_header @url, resp['www-authenticate'], 'POST'

        req = Net::HTTP::Post.new @url.request_uri
        req.content_type = 'application/xml; charset=utf-8'
        req.body = xml
        req.add_field 'Authorization', auth

        puts "Sending w/digest:\n#{req.inspect}\n#{req.to_hash}\n"
        resp = @connection.request req
        puts resp.inspect, resp.to_hash, resp.body, ''
      end

      resp
    end

    def digest_auth
      @digest_auth ||= Net::HTTP::DigestAuth.new
    end
      
    attr_reader :connection
  end
end
