# frozen_string_literal: true

require 'logging'
require 'nokogiri'
require 'uri'
require 'wbem/client'
require 'wbem/version'


module Wbem
  autoload :Object, 'wbem/object'
  autoload :ERRORS, 'wbem/constants'
  autoload :DEFAULT_NAMESPACE, 'wbem/constants'

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

Wbem.logger
