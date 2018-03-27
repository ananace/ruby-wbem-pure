require 'uri'

module Wbem
  class Object
    attr_reader :client, :resource_uri, :node, :body

    def initialize(client_, uri, node_)
      @client = client_
      @resource_uri = URI.parse uri
      @node = node_
      @body = node.at_xpath(".//*[local-name()='Body']")
      @body = @body.child if @body && @body.children.any?
    end

    def classname
      resource_uri.path.split('/').last
    end

    def attributes
      Hash[body.children.map do |child|
        d = [child.name, child.text]
        yield d if block_given?
        d
      end]
    end

    def [](name)
      attributes[name]
    end

    def to_s
      "#{classname}:\n#{attributes.map { |k, v| "  #{k}: #{v.inspect}" }.join "\n"}"
    end
  end
end
