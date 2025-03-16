#!/bin/bash

# ==============================================================================
# SunSync Home Assistant Integration
# Utility Functions
# ==============================================================================

# Log header with timestamp
log_header() {
  local dt=$(date '+%d/%m/%Y %H:%M:%S')
  echo ""
  echo "------------------------------------------------------------------------------"
  echo "-- SunSync - Log"
  echo "------------------------------------------------------------------------------"
  echo "Script execution date & time: $dt"
}

# Clean up old data files
cleanup_old_data() {
  echo "Cleaning up old data."
  rm -rf pvindata.json griddata.json loaddata.json batterydata.json outputdata.json dcactemp.json inverterinfo.json settings.json token.json
}

# Log a message with timestamp
log_message() {
  local level=$1
  local message=$2
  local dt=$(date '+%d/%m/%Y %H:%M:%S')

  case "$level" in
    "INFO")
      echo "[INFO] $dt - $message"
      ;;
    "WARNING")
      echo "[WARNING] $dt - $message"
      ;;
    "ERROR")
      echo "[ERROR] $dt - $message"
      ;;
    *)
      echo "$dt - $message"
      ;;
  esac
}

# Safely exit the script with an error message
safe_exit() {
  local exit_code=$1
  local message=$2

  log_message "ERROR" "$message"
  exit $exit_code
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if required commands exist
check_requirements() {
  local requirements=("curl" "jq")
  local missing_requirements=()

  for req in "${requirements[@]}"; do
    if ! command_exists "$req"; then
      missing_requirements+=("$req")
    fi
  done

  if [ ${#missing_requirements[@]} -gt 0 ]; then
    safe_exit 1 "Missing required commands: ${missing_requirements[*]}"
  fi
}

# Initialize the script
init() {
  check_requirements
  log_header
}
