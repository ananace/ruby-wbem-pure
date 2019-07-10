# frozen_string_literal: true

require 'logging'
require 'nokogiri'
require 'uri'
require 'wbem/client'
require 'wbem/version'

module Wbem
  autoload :ERRORS, 'wbem/constants'
  autoload :DEFAULT_NAMESPACE, 'wbem/constants'
  autoload :Object, 'wbem/object'

  def self.connect(url)
    Wbem::Client.new url
  end

  def self.logger
    @logger ||= begin
      log = Logging.logger[self]
      log.add_appenders Logging.appenders.stdout
      log
    end
  end
end

# Just to initialize the root logger
Wbem.logger
