# frozen_string_literal: true

require 'wbem'

module Wbem
  class Object
    attr_reader :client, :resource_uri, :node

    def initialize(client_, uri, node_)
      @client = client_
      @resource_uri = uri
      @resource_uri = URI.parse resource_uri unless resource_uri.is_a? URI
      @node = node_
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

    def invoke(method, args = {})
      client.invoke(resource_uri.to_s, method, selectors) do |x|
        args.each do |k, v|
          x.send k.to_sym, v
        end

        yield x if block_given?
      end
    end

    def reload
      @node = client.get(resource_uri, selectors).body.document
      load_body
      self
    end

    def selectors(scheme = :hash)
      chosen = attributes.select do |k, _v|
        %w[CreationClassName InstanceID Name SystemCreationClassName SystemName Tag].include?(k)
      end

      if chosen.key? 'InstanceID'
        chosen = { 'InstanceID' => chosen['InstanceID'] }
      end

      if scheme == :xml
        Nokogiri::XML::Builder.new do |x|
          x['w'].SelectorSet('xmlns:w' => 'http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd') do
            chosen.each do |k, v|
              x['w'].Selector(v, 'Name' => k)
            end
          end
        end.doc
      elsif scheme == :hash
        chosen
      end
    end

    def to_epr
      Nokogiri::XML::Builder.new do |x|
        x['a'].EndpointReference(
          'xmlns:a' => 'http://schemas.xmlsoap.org/ws/2004/08/addressing',
          'xmlns:w' => 'http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd'
        ) do
          x['a'].Address('http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous')
          x['a'].ReferenceParameters do
            x['w'].ResourceURI(resource_uri.to_s)
            x << selectors(:xml).to_xml(
              save_with: Nokogiri::XML::Node::SaveOptions::AS_XML |
                         Nokogiri::XML::Node::SaveOptions::NO_DECLARATION
            ).strip
          end
        end
      end.doc
    end

    def to_s
      "#{classname}:\n#{attributes.map { |k, v| "  #{k}: #{v.inspect}" }.join "\n"}"
    end

    def body
      return @body if @body

      @body = node.at_xpath(".//*[local-name()='Body']")
      @body = @body.child if @body && @body.children.any? && @body.child
      @body ||= node
    end
  end
end
