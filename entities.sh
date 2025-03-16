#!/usr/bin/with-contenv bashio

# ==============================================================================
# Home Assistant Entity Management
# Description: Functions for creating and updating Home Assistant entities
# ==============================================================================

# Initialize variables to avoid unbound variable errors
API_BASE_URL_OVERRIDE=""

# Default configuration for entity naming
# These values can be overridden in the add-on configuration
ENTITY_PREFIX="${ENTITY_PREFIX:-sunsync}"
INCLUDE_SERIAL_IN_NAME="${INCLUDE_SERIAL_IN_NAME:-true}"

# Determine which authentication method to use
get_auth_header() {
  # First try to use Supervisor token if available
  if [ -n "$SUPERVISOR_TOKEN" ]; then
    echo "Authorization: Bearer $SUPERVISOR_TOKEN"
  else
    # Fall back to the user-provided token
    echo "Authorization: Bearer $HA_TOKEN"
  fi
}

# Get the Base URL for API calls
get_api_base_url() {
  # Use override if set
  if [ -n "$API_BASE_URL_OVERRIDE" ]; then
    echo "$API_BASE_URL_OVERRIDE"
    return
  fi

  # When using Supervisor token, we can use the supervisor proxy
  if [ -n "$SUPERVISOR_TOKEN" ]; then
    echo "http://supervisor/core/api"
  else
    # Otherwise use the configured URL
    echo "$HTTP_CONNECT_TYPE://$HA_IP:$HA_PORT/api"
  fi
}

# Update Home Assistant entities for a specific inverter
update_ha_entities() {
  local inverter_serial=$1
  local success=0  # Using 0 for success as per bash convention

  # Log the start of entity updates
  log_message "INFO" "Updating Home Assistant entities for inverter: $inverter_serial"

  # Log entity naming configuration
  log_message "INFO" "Entity prefix: $ENTITY_PREFIX, Include serial in name: $INCLUDE_SERIAL_IN_NAME"

  # Get the authentication header
  local auth_header=$(get_auth_header)
  local api_base_url=$(get_api_base_url)

  log_message "INFO" "Using API base URL: $api_base_url"

  # Iterate through all sensor data points and create/update entities
  for key in "${!sensor_data[@]}"; do
    local value="${sensor_data[$key]}"

    # Create entity_id based on configuration
    local entity_id
    if [ "$INCLUDE_SERIAL_IN_NAME" = "true" ]; then
      entity_id="sensor.${ENTITY_PREFIX}_${inverter_serial}_${key}"
    else
      entity_id="sensor.${ENTITY_PREFIX}_${key}"
    fi

    # Create friendly_name based on configuration
    local friendly_name
    if [ "$INCLUDE_SERIAL_IN_NAME" = "true" ]; then
      friendly_name="${ENTITY_PREFIX^} ${inverter_serial} ${key}"
    else
      friendly_name="${ENTITY_PREFIX^} ${key}"
    fi

    # Determine appropriate unit of measurement and device class
    local uom=""
    local device_class=""

    # Apply units based on the sensor type
    case "$key" in
      *_power)
        uom="W"
        device_class="power"
        ;;
      *_energy|*_charge|*_discharge)
        uom="kWh"
        device_class="energy"
        ;;
      *_voltage)
        uom="V"
        device_class="voltage"
        ;;
      *_current)
        uom="A"
        device_class="current"
        ;;
      *_frequency)
        uom="Hz"
        device_class="frequency"
        ;;
      *_temperature|*_temp)
        uom="°C"
        device_class="temperature"
        ;;
      *_soc)
        uom="%"
        device_class="battery"
        ;;
    esac

    # Create or update the entity
    if ! create_or_update_entity "$entity_id" "$friendly_name" "$value" "$uom" "$device_class"; then
      success=1  # Set to 1 to indicate failure
      log_message "ERROR" "Failed to update entity: $entity_id with value: $value"
    elif [ "$ENABLE_VERBOSE_LOG" == "true" ]; then
      echo "$(date '+%d/%m/%Y %H:%M:%S') - Entity $entity_id already exists, updating..."
      echo "$(date '+%d/%m/%Y %H:%M:%S') - Updated entity: $entity_id with value: $value"
    fi
  done

  # Verify that at least some entities are registered
  verify_entities_created "$inverter_serial"

  return $success
}

# Function to create or update a single Home Assistant entity
create_or_update_entity() {
  local entity_id=$1
  local friendly_name=$2
  local state=$3
  local unit_of_measurement=$4
  local device_class=$5

  # Get the authentication header and API base URL
  local auth_header=$(get_auth_header)
  local api_base_url=$(get_api_base_url)

  # Build the Home Assistant API URL
  local ha_api_url="$api_base_url/states/$entity_id"

  # Build proper attributes JSON
  local attributes="{\"friendly_name\": \"$friendly_name\""

  # Only add unit_of_measurement if it's not empty
  if [ ! -z "$unit_of_measurement" ]; then
    attributes="$attributes, \"unit_of_measurement\": \"$unit_of_measurement\""
  fi

  # Only add device_class if it's not empty
  if [ ! -z "$device_class" ]; then
    attributes="$attributes, \"device_class\": \"$device_class\""
  fi

  # Close the attributes JSON
  attributes="$attributes}"

  # Create the payload
  local payload="{\"state\": \"$state\", \"attributes\": $attributes}"

  if [ "$ENABLE_VERBOSE_LOG" == "true" ]; then
    log_message "DEBUG" "Sending to $ha_api_url: $payload"
  fi

  # Make the API call to Home Assistant
  local response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "$auth_header" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$ha_api_url")

  local http_code=$(echo "$response" | tail -n1)
  local result=$(echo "$response" | head -n -1)

  # Log detailed diagnosis for errors
  if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
    log_message "ERROR" "API call failed for entity $entity_id: HTTP $http_code"
    log_message "ERROR" "Response: $result"
    log_message "ERROR" "Attempted URL: $ha_api_url"
    return 1
  elif [[ "$result" == *"error"* ]]; then
    log_message "ERROR" "API returned error for entity $entity_id: $result"
    return 1
  fi

  return 0
}

# Function to check if Home Assistant is reachable
check_ha_connectivity() {
  log_message "INFO" "Testing connection to Home Assistant API"

  # Get the authentication header and API base URL
  local auth_header=$(get_auth_header)
  local api_base_url=$(get_api_base_url)

  log_message "INFO" "Using API URL: $api_base_url"

  # For supervisor, we need to test a different endpoint
  local test_endpoint
  if [ -n "$SUPERVISOR_TOKEN" ]; then
    test_endpoint="$api_base_url/config"  # Changed from /states to /config which is more reliable
  else
    test_endpoint="$api_base_url/"
  fi

  local curl_cmd="curl -s -o /dev/null -w \"%{http_code}\" \
    -H \"$auth_header\" \
    -H \"Content-Type: application/json\" \
    \"$test_endpoint\""

  if [ "$ENABLE_VERBOSE_LOG" == "true" ]; then
    log_message "DEBUG" "Command: $curl_cmd"
  fi

  local result=$(eval $curl_cmd)

  if [ "$result" = "200" ] || [ "$result" = "201" ]; then
    log_message "INFO" "Successfully connected to Home Assistant API"
    # Check API version to ensure compatibility
    check_ha_api_version
    return 0
  else
    log_message "ERROR" "Failed to connect to Home Assistant API. HTTP Status: $result"
    log_message "ERROR" "Please verify your configuration and connectivity"

    # Try a different approach for supervisor
    if [ -n "$SUPERVISOR_TOKEN" ]; then
      log_message "INFO" "Trying alternative supervisor API endpoints..."

      # Try several common supervisor API endpoints
      local endpoints=("http://supervisor/core/api/states" "http://supervisor/core/api/config" "http://supervisor/core/api")

      for endpoint in "${endpoints[@]}"; do
        log_message "INFO" "Trying endpoint: $endpoint"
        local alt_result=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "$auth_header" \
          -H "Content-Type: application/json" \
          "$endpoint")

        if [ "$alt_result" = "200" ] || [ "$alt_result" = "201" ]; then
          log_message "INFO" "Alternative supervisor endpoint works: $endpoint"
          # Update the API_BASE_URL_OVERRIDE environment variable
          export API_BASE_URL_OVERRIDE="${endpoint%/*}"  # Remove last path component
          log_message "INFO" "Setting API_BASE_URL_OVERRIDE to $API_BASE_URL_OVERRIDE"
          check_ha_api_version
          return 0
        fi
      done
    fi

    return 1
  fi
}

# New function to check Home Assistant API version
check_ha_api_version() {
  local auth_header=$(get_auth_header)
  local api_base_url=$(get_api_base_url)

  # If we have an override API base URL, use it
  if [ -n "$API_BASE_URL_OVERRIDE" ]; then
    api_base_url="$API_BASE_URL_OVERRIDE"
  fi

  log_message "INFO" "Checking Home Assistant API version..."

  # Try to get API version info
  local response=$(curl -s -w "\n%{http_code}" \
    -H "$auth_header" \
    -H "Content-Type: application/json" \
    "$api_base_url/")

  local http_code=$(echo "$response" | tail -n1)
  local result=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    # Extract version if possible
    if [[ "$result" == *"version"* ]]; then
      local version=$(echo "$result" | grep -o '"version": *"[^"]*"' | cut -d'"' -f4)
      log_message "INFO" "Home Assistant API version: $version"

      # Store the API version for later use
      export HA_API_VERSION="$version"

      # Determine correct entity registry endpoint based on version
      determine_entity_registry_endpoint "$version"
    else
      log_message "WARNING" "Could not determine Home Assistant API version"
    fi
  else
    log_message "WARNING" "Could not determine Home Assistant API version. HTTP status: $http_code"
  fi
}

# New function to determine the correct entity registry endpoint
determine_entity_registry_endpoint() {
  local version="$1"

  # Default endpoint for entity registry
  ENTITY_REGISTRY_ENDPOINT="config/entity_registry/registry"

  # For newer versions of Home Assistant (2023.x and above)
  if [[ "$version" =~ ^202[3-9]\. ]]; then
    ENTITY_REGISTRY_ENDPOINT="config/entity_registry/entity"
    log_message "INFO" "Using modern entity registry endpoint: $ENTITY_REGISTRY_ENDPOINT"
  else
    log_message "INFO" "Using legacy entity registry endpoint: $ENTITY_REGISTRY_ENDPOINT"
  fi

  export ENTITY_REGISTRY_ENDPOINT
}

# Verify at least some entities were successfully created
verify_entities_created() {
  local inverter_serial=$1

  # Create sample entity name based on configuration
  local sample_entity
  if [ "$INCLUDE_SERIAL_IN_NAME" = "true" ]; then
    sample_entity="sensor.${ENTITY_PREFIX}_${inverter_serial}_battery_soc"
  else
    sample_entity="sensor.${ENTITY_PREFIX}_battery_soc"
  fi

  # Get the authentication header and API base URL
  local auth_header=$(get_auth_header)
  local api_base_url=$(get_api_base_url)

  log_message "INFO" "Verifying entity creation by checking for sample entity: $sample_entity"

  local response=$(curl -s -w "\n%{http_code}" -X GET \
    -H "$auth_header" \
    -H "Content-Type: application/json" \
    "$api_base_url/states/$sample_entity")

  local http_code=$(echo "$response" | tail -n1)
  local result=$(echo "$response" | head -n -1)

  if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
    log_message "ERROR" "Verification failed! Sample entity not found (HTTP $http_code)"
    log_message "ERROR" "Possible issues:"
    log_message "ERROR" "1. Your token may not have the correct permissions"
    log_message "ERROR" "2. Home Assistant may be rejecting the entity format"
    log_message "ERROR" "3. Network connectivity issues between add-on and Home Assistant"
    log_message "ERROR" "Trying a diagnostic API call to list all entities..."

    # Try to get all entities
    local all_entities=$(curl -s -X GET \
      -H "$auth_header" \
      -H "Content-Type: application/json" \
      "$api_base_url/states" | grep -c "entity_id" || echo "0")

    log_message "INFO" "Found approximately $all_entities entities total in Home Assistant"
    log_message "INFO" "If this number is 0, your token likely doesn't have correct permissions"

    # Search for any of our entities
    local our_entities=$(curl -s -X GET \
      -H "$auth_header" \
      -H "Content-Type: application/json" \
      "$api_base_url/states" | grep -c "$ENTITY_PREFIX" || echo "0")

    log_message "INFO" "Found approximately $our_entities ${ENTITY_PREFIX^} entities"

    # Try to register the entity in the registry as a last resort
    register_entity_in_registry "$inverter_serial" "$sample_entity"

    return 1
  else
    log_message "INFO" "Entity verification successful. Sample entity exists."
    return 0
  fi
}

# Register an entity in the registry
register_entity_in_registry() {
  local inverter_serial=$1
  local entity_id=$2

  # Get the authentication header and API base URL
  local auth_header=$(get_auth_header)
  local api_base_url=$(get_api_base_url)

  log_message "INFO" "Attempting to register entity in registry: $entity_id"

  # Use the determined endpoint (or default if not set)
  local endpoint="${ENTITY_REGISTRY_ENDPOINT:-config/entity_registry/entity}"

  # Create friendly name based on configuration
  local entity_name
  if [ "$INCLUDE_SERIAL_IN_NAME" = "true" ]; then
    entity_name="${ENTITY_PREFIX^} $inverter_serial Battery SOC"
  else
    entity_name="${ENTITY_PREFIX^} Battery SOC"
  fi

  local payload="{\"entity_id\": \"$entity_id\", \"name\": \"$entity_name\", \"device_class\": \"battery\"}"

  log_message "INFO" "Using entity registry endpoint: $api_base_url/$endpoint"

  local response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "$auth_header" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$api_base_url/$endpoint")

  local http_code=$(echo "$response" | tail -n1)
  local result=$(echo "$response" | head -n -1)

  if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
    log_message "WARNING" "Could not register entity in registry: $entity_id (HTTP $http_code)"
    log_message "WARNING" "Response: $result"

    # Try alternative endpoint if the first one failed
    if [ "$endpoint" = "config/entity_registry/entity" ]; then
      log_message "INFO" "Trying alternative entity registry endpoint..."
      local alt_endpoint="config/entity_registry/registry"

      response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "$auth_header" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$api_base_url/$alt_endpoint")

      http_code=$(echo "$response" | tail -n1)
      result=$(echo "$response" | head -n -1)

      if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log_message "INFO" "Successfully registered entity using alternative endpoint"
        ENTITY_REGISTRY_ENDPOINT="$alt_endpoint"
        return 0
      fi
    fi

    return 1
  else
    log_message "INFO" "Successfully registered entity in registry: $entity_id"
    return 0
  fi
}

# Add a diagnostic function to debug Home Assistant configuration
diagnose_ha_setup() {
  log_message "INFO" "===== DIAGNOSTIC INFORMATION ====="
  log_message "INFO" "Entity naming configuration:"
  log_message "INFO" "  Prefix: $ENTITY_PREFIX"
  log_message "INFO" "  Include serial numbers: $INCLUDE_SERIAL_IN_NAME"

  # Check which authentication method is available
  if [ -n "$SUPERVISOR_TOKEN" ]; then
    log_message "INFO" "Using Supervisor token for authentication"
    log_message "INFO" "Token length: ${#SUPERVISOR_TOKEN}"
    log_message "INFO" "API URL: http://supervisor/core/api"
  else
    log_message "INFO" "Using long-lived token for authentication"
    log_message "INFO" "Home Assistant URL: $HTTP_CONNECT_TYPE://$HA_IP:$HA_PORT"
    log_message "INFO" "Token length: ${#HA_TOKEN}"
    log_message "INFO" "Token starting characters: ${HA_TOKEN:0:5}..."
  fi

  # Show addon info
  if command -v bashio >/dev/null 2>&1; then
    log_message "INFO" "Add-on version: $(bashio::addon.version)"
    log_message "INFO" "Add-on name: $(bashio::addon.name)"
  fi

  # Check if we can access Home Assistant at all
  log_message "INFO" "Testing basic connectivity..."
  local auth_header=$(get_auth_header)
  local api_base_url=$(get_api_base_url)

  local basic_conn=$(curl -s -I -o /dev/null -w "%{http_code}" "$api_base_url/")
  log_message "INFO" "Basic connectivity: HTTP $basic_conn"

  # Validate token format if using long-lived token
  if [ -z "$SUPERVISOR_TOKEN" ] && [ -n "$HA_TOKEN" ]; then
    if [[ ! "$HA_TOKEN" =~ ^[a-zA-Z0-9_\.\-]+$ ]]; then
      log_message "WARNING" "Token contains potentially invalid characters"
    fi
  fi

  # Attempt to get API status
  log_message "INFO" "Testing API access..."
  local response=$(curl -s -w "\n%{http_code}" \
    -H "$auth_header" \
    -H "Content-Type: application/json" \
    "$api_base_url/")

  local http_code=$(echo "$response" | tail -n1)
  local result=$(echo "$response" | head -n -1)

  log_message "INFO" "API access result: HTTP $http_code"
  if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
    log_message "ERROR" "API access failed"
  else
    log_message "INFO" "API access successful"

    # Check if we can see any entities
    local entities_count=$(curl -s -X GET \
      -H "$auth_header" \
      -H "Content-Type: application/json" \
      "$api_base_url/states" | grep -c "entity_id" || echo "0")

    log_message "INFO" "Found $entities_count entities in Home Assistant"

    # Look for our entities
    local our_entities=$(curl -s -X GET \
      -H "$auth_header" \
      -H "Content-Type: application/json" \
      "$api_base_url/states" | grep -c "$ENTITY_PREFIX" || echo "0")

    log_message "INFO" "Found $our_entities ${ENTITY_PREFIX^} entities in Home Assistant"
  fi

  log_message "INFO" "===== END DIAGNOSTIC INFORMATION ====="
}

# Simple function to check basic connectivity
check_basic_connectivity() {
  local url="$1"
  local timeout=3

  # Use curl with a short timeout to check if the URL is accessible
  if curl -s --head --fail --connect-timeout "$timeout" "$url" >/dev/null 2>&1; then
    return 0  # Success
  else
    return 1  # Failure
  fi
}
