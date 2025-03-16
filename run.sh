#!/usr/bin/with-contenv bashio

# ==============================================================================
# SunSync Home Assistant Integration
# Author: jujo1
# Original Author: martinville
# Description: Connects to the SunSynk API and creates/updates Home Assistant entities with solar system data
#
# This script coordinates the modules:
# - utils.sh: Common utility functions
# - config.sh: Configuration management
# - api.sh: API communication
# - data.sh: Data parsing and processing
# - entities.sh: Home Assistant entity creation and management
# ==============================================================================

# Disable exit on error to prevent script from terminating on recoverable errors
set +e

# Current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source all modules
source "/utils.sh"
source "/config.sh"
source "/api.sh"
source "/data.sh"
source "/entities.sh"
source "/init.sh"

# Make sure the files are executable
chmod +x /utils.sh /config.sh /api.sh /data.sh /entities.sh /init.sh

# Get a value from the config file
get_config_value() {
  local key=$1
  local default_value=$2
  local value

  # Check if config.json exists
  if [ -f "/data/options.json" ]; then
    value=$(jq -r ".$key // \"\"" /data/options.json)
    if [ -z "$value" ] || [ "$value" == "null" ]; then
      value=$default_value
    fi
  else
    value=$default_value
  fi

  echo "$value"
}

# Main program function that executes the full workflow
main() {
  log_header

  # Load configuration from Home Assistant
  if ! load_config; then
    log_message "ERROR" "Failed to load configuration. Exiting."
    exit 1
  fi

  # Check SUPERVISOR_TOKEN availability
  if [ -n "$SUPERVISOR_TOKEN" ]; then
    log_message "INFO" "Supervisor token found, length: ${#SUPERVISOR_TOKEN}"
  else
    log_message "INFO" "No Supervisor token available, will use long-lived token"
  fi

  if [ "$ENABLE_VERBOSE_LOG" == "true" ]; then
    log_message "INFO" "Starting SunSync integration with verbose logging enabled"
  else
    log_message "INFO" "Starting SunSync integration"
  fi

  log_message "INFO" "Using HTTP connect type: $HTTP_CONNECT_TYPE"
  log_message "INFO" "Refresh rate set to: $REFRESH_RATE seconds"

  # Run diagnostics to identify any configuration issues
  diagnose_ha_setup

  # Check if we can connect to Home Assistant before starting
  if ! check_ha_connectivity; then
    # If supervisor token fails, try with long-lived token directly
    if [ -n "$SUPERVISOR_TOKEN" ] && [ -n "$HA_TOKEN" ]; then
      log_message "WARNING" "Supervisor API connection failed. Trying with direct connection using long-lived token."
      unset SUPERVISOR_TOKEN

      if check_ha_connectivity; then
        log_message "INFO" "Direct connection successful. Proceeding with long-lived token."
      else
        log_message "ERROR" "Cannot connect to Home Assistant with either method. Please check your configuration."
        exit 1
      fi
    else
      log_message "ERROR" "Cannot connect to Home Assistant. Please check your configuration."
      exit 1
    fi
  fi

  # Initialize the SunSync environment (clean/prepare entities)
  if ! initialize_sunsync; then
    log_message "WARNING" "Initialization process encountered issues. Continuing anyway."
  fi

  # Main loop
  while true; do
    cleanup_old_data

    if get_auth_token && validate_token; then
      IFS=';'
      for inverter_serial in $SUNSYNK_SERIAL; do
        log_message "INFO" "Processing inverter with serial: $inverter_serial"

        if fetch_inverter_data "$inverter_serial"; then
          # Parse the data
          if parse_inverter_data "$inverter_serial"; then
            # Check if we have data to process
            if [ ${#sensor_data[@]} -eq 0 ]; then
              log_message "WARNING" "No valid data retrieved for inverter $inverter_serial"
            else
              log_message "INFO" "Successfully parsed data for inverter $inverter_serial with ${#sensor_data[@]} data points"

              # Create or update the entities in Home Assistant
              if update_ha_entities "$inverter_serial"; then
                log_message "INFO" "Successfully updated Home Assistant entities for inverter $inverter_serial"
              else
                log_message "ERROR" "Failed to update some Home Assistant entities for inverter $inverter_serial"
                log_message "ERROR" "This usually indicates a problem with the Home Assistant API connection"
                log_message "ERROR" "Please check your configuration and network connection"
                diagnose_ha_setup
              fi
            fi
          else
            log_message "ERROR" "Failed to parse data for inverter $inverter_serial"
          fi
        else
          log_message "ERROR" "Failed to fetch complete data for inverter $inverter_serial. Will retry on next iteration."
        fi
      done
      unset IFS

      log_message "INFO" "Processing cycle completed successfully"
    else
      log_message "ERROR" "Authentication failed. Will retry on next iteration."
    fi

    log_message "INFO" "All done! Waiting $REFRESH_RATE seconds before next update."
    sleep "$REFRESH_RATE"
  done
}

# Start the main program
main
