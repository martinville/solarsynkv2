#!/bin/bash

# ==============================================================================
# Sunsync Home Assistant Integration
# API Communication Functions
# ==============================================================================

# Global API variables
SERVER_API_BEARER_TOKEN=""
SERVER_API_BEARER_TOKEN_SUCCESS=""
SERVER_API_BEARER_TOKEN_MSG=""

# Default retry configuration - used across all API functions
DEFAULT_MAX_RETRIES=3
DEFAULT_RETRY_DELAY=30

# Get authentication token from Sunsynk API
get_auth_token() {
  log_message "INFO" "Getting bearer token from solar service provider's API."

  local retry_count=0
  local output_file="token.json"

  while [ $retry_count -lt $DEFAULT_MAX_RETRIES ]; do
    # Fetch the token using our standardized api_call function
    if api_call "POST" "https://api.sunsynk.net/oauth/token" "$output_file" \
         "Content-Type: application/json" \
         "-d {\"areaCode\": \"sunsynk\",\"client_id\": \"csp-web\",\"grant_type\": \"password\",\"password\": \"$SUNSYNK_PASS\",\"source\": \"sunsynk\",\"username\": \"$SUNSYNK_USER\"}"; then

      # Check if file exists before attempting to parse
      if [ ! -f "$output_file" ]; then
        log_message "ERROR" "Token response file not found"
        retry_count=$((retry_count + 1))
        sleep $DEFAULT_RETRY_DELAY
        continue
      fi

      # Check verbose logging
      if [ "$ENABLE_VERBOSE_LOG" == "true" ]; then
        echo "Raw token data"
        echo ------------------------------------------------------------------------------
        echo "token.json"
        cat "$output_file"
        echo ------------------------------------------------------------------------------
      fi

      # Parse token from response with error checking
      if ! SERVER_API_BEARER_TOKEN=$(jq -r '.data.access_token // empty' "$output_file" 2>/dev/null); then
        log_message "ERROR" "Failed to parse token data"
        retry_count=$((retry_count + 1))
        sleep $DEFAULT_RETRY_DELAY
        continue
      fi

      if ! SERVER_API_BEARER_TOKEN_SUCCESS=$(jq -r '.success // "false"' "$output_file" 2>/dev/null); then
        log_message "ERROR" "Failed to parse token success status"
        retry_count=$((retry_count + 1))
        sleep $DEFAULT_RETRY_DELAY
        continue
      fi

      if [ "$SERVER_API_BEARER_TOKEN_SUCCESS" == "true" ] && [ ! -z "$SERVER_API_BEARER_TOKEN" ]; then
        log_message "INFO" "Valid token retrieved."
        log_message "INFO" "Bearer Token length: ${#SERVER_API_BEARER_TOKEN}"
        return 0
      else
        SERVER_API_BEARER_TOKEN_MSG=$(jq -r '.msg // "Unknown error"' "$output_file" 2>/dev/null)
        log_message "WARNING" "Invalid token received: $SERVER_API_BEARER_TOKEN_MSG. Retrying after a sleep..."
        sleep $DEFAULT_RETRY_DELAY
        retry_count=$((retry_count + 1))
      fi
    else
      log_message "ERROR" "Error getting token. Retrying in $DEFAULT_RETRY_DELAY seconds..."
      sleep $DEFAULT_RETRY_DELAY
      retry_count=$((retry_count + 1))
    fi
  done

  if [ $retry_count -ge $DEFAULT_MAX_RETRIES ]; then
    log_message "ERROR" "Maximum retries reached. Cannot obtain auth token."
    return 1
  fi

  return 0
}

# Validate token
validate_token() {
  if [ -z "$SERVER_API_BEARER_TOKEN" ]; then
    log_message "ERROR" "****Token could not be retrieved due to the following possibilities****"
    log_message "ERROR" "Incorrect setup, please check the configuration tab."
    log_message "ERROR" "Either this HA instance cannot reach Sunsynk.net due to network problems or the Sunsynk server is down."
    log_message "ERROR" "The Sunsynk server admins are rejecting due to too frequent connection requests."
    log_message "ERROR" "This Script will not continue but will retry on next iteration. No values were updated."
    return 1
  fi

  log_message "INFO" "Sunsynk Server API Token: Hidden for security reasons"
  log_message "INFO" "Note: Setting the refresh rate of this addon to be lower than the update rate of the SunSynk server will not increase the actual update rate."
  return 0
}

# Generic function for performing API calls with retries
api_call() {
  local method=$1  # GET, POST, etc.
  local url=$2
  local output_file=$3
  local headers=("${@:4}")  # All remaining args are headers
  local retry_count=0
  local data=""

  # Extract data if this is a POST request
  if [[ "$method" == "POST" && "${headers[*]}" == *"Content-Type: application/json"* ]]; then
    # Find the data in the headers
    for header in "${headers[@]}"; do
      if [[ "$header" == "-d "* ]]; then
        data="${header#-d }"
        break
      fi
    done
  fi

  while [ $retry_count -lt $DEFAULT_MAX_RETRIES ]; do
    # Build the curl command dynamically
    local curl_cmd="curl -s -f -S -k -X $method"

    # Add headers
    for header in "${headers[@]}"; do
      if [[ "$header" != "-d "* ]]; then  # Skip data, we'll add it separately
        curl_cmd="$curl_cmd -H \"$header\""
      fi
    done

    # Add data if it exists
    if [ ! -z "$data" ]; then
      curl_cmd="$curl_cmd -d '$data'"
    fi

    # Add the URL and output file
    curl_cmd="$curl_cmd \"$url\" -o \"$output_file\""

    # Execute the command
    if eval $curl_cmd; then
      # Check if the output file exists and is not empty (for responses that expect data)
      if [ "$output_file" != "/dev/null" ] && [ ! -s "$output_file" ]; then
        log_message "WARNING" "API call returned empty response: $method $url"
        retry_count=$((retry_count + 1))

        if [ $retry_count -lt $DEFAULT_MAX_RETRIES ]; then
          log_message "INFO" "Retrying in 5 seconds..."
          sleep 5
          continue
        fi
      fi
      return 0
    else
      log_message "WARNING" "API call failed: $method $url, attempt $(($retry_count + 1))/$DEFAULT_MAX_RETRIES"
      retry_count=$((retry_count + 1))

      if [ $retry_count -lt $DEFAULT_MAX_RETRIES ]; then
        log_message "INFO" "Retrying in 5 seconds..."
        sleep 5
      fi
    fi
  done

  log_message "ERROR" "API call failed after $DEFAULT_MAX_RETRIES attempts: $method $url"
  return 1
}

# Make an API call to the Sunsynk API
sunsynk_api_call() {
  local endpoint=$1
  local output_file=$2

  # Validate parameters
  if [ -z "$endpoint" ] || [ -z "$output_file" ]; then
    log_message "ERROR" "Missing required parameters for sunsynk_api_call"
    return 1
  fi

  if [ -z "$SERVER_API_BEARER_TOKEN" ]; then
    log_message "ERROR" "No valid bearer token available for API call"
    return 1
  fi

  api_call "GET" "$endpoint" "$output_file" \
    "Content-Type: application/json" \
    "authorization: Bearer $SERVER_API_BEARER_TOKEN"
}

# Make an API call to the Home Assistant API
ha_api_call() {
  local endpoint=$1
  local method=${2:-"GET"}
  local data=${3:-""}
  local output_file=${4:-"/dev/null"}

  # Validate parameters
  if [ -z "$endpoint" ]; then
    log_message "ERROR" "Missing required parameters for ha_api_call"
    return 1
  fi

  if [ -z "$HA_TOKEN" ]; then
    log_message "ERROR" "No valid HA token available for API call"
    return 1
  fi

  local url="$HTTP_CONNECT_TYPE://$HA_IP:$HA_PORT$endpoint"

  local headers=(
    "Authorization: Bearer $HA_TOKEN"
    "Content-Type: application/json"
  )

  if [ ! -z "$data" ]; then
    headers+=("-d $data")
  fi

  api_call "$method" "$url" "$output_file" "${headers[@]}"
}

# Send settings to Sunsynk inverter via API
send_inverter_settings() {
  local inverter_sn=$1
  local settings_data=$2
  local retry_count=0

  # Validate parameters
  if [ -z "$inverter_sn" ] || [ -z "$settings_data" ]; then
    log_message "ERROR" "Missing required parameters for send_inverter_settings"
    return 1
  fi

  # Validate JSON format of settings_data
  if ! echo "$settings_data" | jq empty 2>/dev/null; then
    log_message "ERROR" "Invalid JSON format in settings data"
    return 1
  fi

  local endpoint="https://api.sunsynk.net/api/v1/common/setting/$inverter_sn/set"
  local output_file="inverter_settings_response.json"

  log_message "INFO" "Sending settings to inverter $inverter_sn"

  if [ "$ENABLE_VERBOSE_LOG" == "true" ]; then
    echo "Sending settings data:"
    echo "$settings_data"
  fi

  # Try with retry logic
  while [ $retry_count -lt $DEFAULT_MAX_RETRIES ]; do
    # Make POST request to update inverter settings
    api_call "POST" "$endpoint" "$output_file" \
      "Content-Type: application/json" \
      "authorization: Bearer $SERVER_API_BEARER_TOKEN" \
      "-d $settings_data"

    local status=$?

    if [ $status -eq 0 ]; then
      # Check if response file exists
      if [ ! -f "$output_file" ]; then
        log_message "ERROR" "Settings response file not found"
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $DEFAULT_MAX_RETRIES ]; then
          log_message "INFO" "Retrying in $DEFAULT_RETRY_DELAY seconds..."
          sleep $DEFAULT_RETRY_DELAY
          continue
        fi
        return 1
      fi

      # Verbose logging of response
      if [ "$ENABLE_VERBOSE_LOG" == "true" ]; then
        echo "Settings response:"
        echo ------------------------------------------------------------------------------
        cat "$output_file"
        echo ------------------------------------------------------------------------------
      fi

      # Check if response indicates success
      local success
      if ! success=$(jq -r '.success // "false"' "$output_file" 2>/dev/null); then
        log_message "ERROR" "Failed to parse settings response"
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $DEFAULT_MAX_RETRIES ]; then
          log_message "INFO" "Retrying in $DEFAULT_RETRY_DELAY seconds..."
          sleep $DEFAULT_RETRY_DELAY
          continue
        fi
        return 1
      fi

      if [ "$success" == "true" ]; then
        log_message "INFO" "Successfully updated inverter settings"
        return 0
      else
        local error_msg
        if ! error_msg=$(jq -r '.msg // "Unknown error"' "$output_file" 2>/dev/null); then
          error_msg="Failed to parse error message"
        fi
        log_message "ERROR" "Failed to update inverter settings: $error_msg"
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $DEFAULT_MAX_RETRIES ]; then
          log_message "INFO" "Retrying in $DEFAULT_RETRY_DELAY seconds..."
          sleep $DEFAULT_RETRY_DELAY
          continue
        fi
        return 1
      fi
    else
      log_message "ERROR" "Failed to send settings to inverter $inverter_sn"
      retry_count=$((retry_count + 1))
      if [ $retry_count -lt $DEFAULT_MAX_RETRIES ]; then
        log_message "INFO" "Retrying in $DEFAULT_RETRY_DELAY seconds..."
        sleep $DEFAULT_RETRY_DELAY
      else
        return 1
      fi
    fi
  done

  log_message "ERROR" "Failed to update inverter settings after $DEFAULT_MAX_RETRIES attempts"
  return 1
}

# Example usage:
# send_inverter_settings "INV123456789" '{"workMode":1,"gridChargeEnable":true,"batteryType":1,"batteryCapacity":200}'
