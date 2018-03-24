require 'uri'

module Wbem
  class Object
    attr_reader :client, :resource_uri, :node, :body

    def initialize client_, uri, node_
      @client = client_
      @resource_uri = URI.parse uri
      @node = node_
      
      ns = node.namespaces.find { |k,v| v == 'http://www.w3.org/2003/05/soap-envelope' }.first.split(':').last rescue ""
      @body = node.at_xpath(".//#{ns}:Body").child rescue node
    end

    def classname
      resource_uri.path.split('/').last
    end

    def attributes(&block)
      Hash[body.children.map do |child|
        d = [ child.name, child.text ]
        yield d if block_given?
        d
      end]
    end

    def [] name
      attributes[name]
    end

    def to_s
      "#{classname}:\n#{attributes.map {|k,v| "  #{k}: #{v.inspect}"}.join "\n"}"
    end
  end
end
