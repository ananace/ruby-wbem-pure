require 'logging'
require 'wbem/client'
require 'wbem/version'

#
module Wbem
  def self.connect(url)
    Wbem::Client.new url
  end

  private

  def self.logger
    @@logger ||= (
      log = Logging.logger['wbem']
      log.add_appenders Logging.appenders.stdout
      log
    )
  end
end
