# frozen_string_literal: true

require 'logger'
require 'time'

module Spectre
  module Logging
    def logger
      @logger ||= create_logger
    end

    def log_error(message)
      logger.error(message)
    end

    def log_info(message)
      logger.info(message)
    end

    def log_debug(message)
      logger.debug(message)
    end

    private

    def create_logger
      Logger.new(STDOUT).tap do |log|
        log.progname = 'Spectre'
        log.level = Logger::DEBUG # Set the default log level (can be changed to INFO, WARN, etc.)
        log.formatter = proc do |severity, datetime, progname, msg|
          "#{datetime.utc.iso8601} #{severity} #{progname}: #{msg}\n"
        end
      end
    end
  end
end
