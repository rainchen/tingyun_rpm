# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

#

module TingYun
  module Agent
    # An exception that is thrown by the server if the agent license is invalid.
    class LicenseException < StandardError; end

    # An exception that forces an agent to stop reporting until its mongrel is restarted.
    class ForceDisconnectException < StandardError; end

    # An exception that forces an agent to restart.
    class ForceRestartException < StandardError; end

    # Used to blow out of a periodic task without logging a an error, such as for routine
    # failures.
    class ServerConnectionException < StandardError; end

    # When a post is either too large or poorly formatted we should
    # drop it and not try to resend
    class UnrecoverableServerException < ServerConnectionException; end

    # An unrecoverable client-side error that prevents the agent from continuing
    class UnrecoverableAgentException < ServerConnectionException; end

    # An error while serializing data for the collector
    class SerializationError < StandardError; end

    class BackgroundLoadingError < StandardError; end

    def handle_force_disconnect(error)
      Agent.logger.warn "Ting Yun forced this agent to disconnect (#{error.message})"
      disconnect
    end

    # When the server sends us an error with the license key, we
    # want to tell the user that something went wrong, and let
    # them know where to go to get a valid license key
    #
    # After this runs, it disconnects the agent so that it will
    # no longer try to connect to the server, saving the
    # application and the server load
    def handle_license_error(error)
      Agent.logger.error(\
              error.message, \
              "You need to obtain a valid license key, or to upgrade your account.")
      disconnect
    end

    def handle_unrecoverable_agent_error(error)
      Agent.logger.error(error.message)
      disconnect
      shutdown
    end

    # When we have a problem connecting to the server, we need
    # to tell the user what happened, since this is not an error
    # we can handle gracefully.
    def log_error(error)
      Agent.logger.error "Error establishing connection with Ting Yun Service at #{server}:", error
    end

    # Handles an unknown error in the worker thread by logging
    # it and disconnecting the agent, since we are now in an
    # unknown state.
    def handle_other_error(error)
      Agent.logger.error "Unhandled error in worker thread, disconnecting this agent process:"
      # These errors are fatal (that is, they will prevent the agent from
      # reporting entirely), so we really want backtraces when they happen
      Agent.logger.log_exception(:error, error)
      disconnect
    end

    # Handles the case where the server tells us to restart -
    # this clears the data, clears connection attempts, and
    # waits a while to reconnect.
    def handle_force_restart(error)
      Agent.logger.debug error.message
      drop_buffered_data
      @service.force_restart if @service
      @connect_state = :pending
      sleep 30
    end



  end
end