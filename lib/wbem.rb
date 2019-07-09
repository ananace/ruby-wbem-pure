# frozen_string_literal: true

require 'logging'
require 'wbem/client'
require 'wbem/version'

module Wbem
  def self.connect(url)
    Wbem::Client.new url
  end

  def self.logger
    @logger ||= begin
      log = Logging.logger['wbem']
      log.add_appenders Logging.appenders.stdout
      log
    end
  end
end
