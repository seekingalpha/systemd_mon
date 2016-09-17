require 'systemd_mon/error'
require 'systemd_mon/notifiers/base'

begin
  require 'pagerduty'
rescue LoadError
  raise SystemdMon::NotifierDependencyError, "The 'pagerduty' gem is required by the pagerduty notifier"
end

module SystemdMon::Notifiers
  class Pagerduty < Base
    def initialize(*)
      super
      self.client = ::Pagerduty.new(options['api_key'])
      self.environ = options.has_key?('environ') ? options['environ'] : 'no_env'
    end

    def notify_start!(hostname)
      log "SystemdMon is starting on #{hostname}"
    end

    def notify_stop!(hostname)
      log "SystemdMon is stopping on #{hostname}"
    end

    def notify!(notification)
      case notification.type
      when :alert
        log 'PD handling alert'
        log "status_text: #{notification.unit.state_change.status_text}, last:#{notification.unit.state_change.last}"
        handle_notification_alert(notification)
      else
        log "PD handling #{notification.type}"
      end

    end

    protected
      attr_accessor :client, :environ

      def handle_notification_alert(notification)
        unit = notification.unit
        state_change = unit.state_change
        hostname = notification.hostname
        incident_key = "systemd/#{hostname}/#{unit.name}"
        if state_change.fail?
          incident_desc = "#{environ.capitalize} systemd unit #{unit.name} failed on #{hostname}"
          details = {
           Hostname: hostname,
           Unit: unit.name,
           Changes: state_change.to_s
          }
          debug "Triggering incident:\n Desc: #{incident_desc}\n Key: #{incident_key}\n Details: #{details}"
          client.trigger(incident_desc, incident_key: incident_key, details: details)
        else
          debug "Resolving incident:\n #{incident_key}"
          incident = client.get_incident(incident_key)
          incident.resolve()
        end
      end
  end
end
