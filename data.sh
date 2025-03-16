#!/bin/bash

# ==============================================================================
# Sunsync Home Assistant Integration
# Data Fetching and Parsing Functions
# ==============================================================================

# Global data storage - associative array
declare -A sensor_data

# Fetch data for a specific inverter
fetch_inverter_data() {
  local inverter_serial=$1
  local curl_error=0

  echo ""
  log_message "INFO" "Fetching data for serial: $inverter_serial"
  log_message "INFO" "Please wait while curl is fetching input, grid, load, battery & output data..."

  # PV input data
  if ! sunsynk_api_call "https://api.sunsynk.net/api/v1/inverter/$inverter_serial/realtime/input" "pvindata.json"; then
    curl_error=1
  fi

  # Grid data
  if ! sunsynk_api_call "https://api.sunsynk.net/api/v1/inverter/grid/$inverter_serial/realtime?sn=$inverter_serial" "griddata.json"; then
    curl_error=1
  fi

  # Load data
  if ! sunsynk_api_call "https://api.sunsynk.net/api/v1/inverter/load/$inverter_serial/realtime?sn=$inverter_serial" "loaddata.json"; then
    curl_error=1
  fi

  # Battery data
  if ! sunsynk_api_call "https://api.sunsynk.net/api/v1/inverter/battery/$inverter_serial/realtime?sn=$inverter_serial&lan=en" "batterydata.json"; then
    curl_error=1
  fi

  # Output data
  if ! sunsynk_api_call "https://api.sunsynk.net/api/v1/inverter/$inverter_serial/realtime/output" "outputdata.json"; then
    curl_error=1
  fi

  # Temperature data
  if ! sunsynk_api_call "https://api.sunsynk.net/api/v1/inverter/$inverter_serial/output/day?lan=en&date=$VarCurrentDate&column=dc_temp,igbt_temp" "dcactemp.json"; then
    curl_error=1
  fi

  # Inverter info
  if ! sunsynk_api_call "https://api.sunsynk.net/api/v1/inverter/$inverter_serial" "inverterinfo.json"; then
    curl_error=1
  fi

  # Settings
  if ! sunsynk_api_call "https://api.sunsynk.net/api/v1/common/setting/$inverter_serial/read" "settings.json"; then
    curl_error=1
  fi

  if [ $curl_error -eq 1 ]; then
    log_message "WARNING" "Some data endpoints failed to fetch. Data may be incomplete."
  fi

  return $curl_error
}

# Parse data from JSON files
parse_inverter_data() {
  local inverter_serial=$1

  # Show inverter information
  local inverterinfo_brand=$(jq -r '.data.brand' inverterinfo.json)
  local inverterinfo_status=$(jq -r '.data.status' inverterinfo.json)
  local inverterinfo_runstatus=$(jq -r '.data.runStatus' inverterinfo.json)
  local inverterinfo_ratepower=$(jq -r '.data.ratePower' inverterinfo.json)
  local inverterinfo_plantid=$(jq -r '.data.plant.id' inverterinfo.json)
  local inverterinfo_plantname=$(jq -r '.data.plant.name' inverterinfo.json)
  local inverterinfo_serial=$(jq -r '.data.sn' inverterinfo.json)

  echo ------------------------------------------------------------------------------
  log_message "INFO" "Inverter Information"
  log_message "INFO" "Brand: $inverterinfo_brand"
  log_message "INFO" "Status: $inverterinfo_runstatus"
  log_message "INFO" "Max Watts: $inverterinfo_ratepower"
  log_message "INFO" "Plant ID: $inverterinfo_plantid"
  log_message "INFO" "Plant Name: $inverterinfo_plantname"
  log_message "INFO" "Inverter S/N: $inverterinfo_serial"
  echo ------------------------------------------------------------------------------

  log_message "INFO" "Data fetched for serial $inverter_serial. Enable verbose logging to see more information."

  # Reset the sensor data array
  sensor_data=()

  # Parse all the different data points
  # Battery data
  sensor_data["battery_capacity"]=$(jq -r '.data.capacity // "0"' batterydata.json)
  sensor_data["battery_chargevolt"]=$(jq -r '.data.chargeVolt // "0"' batterydata.json)
  sensor_data["battery_current"]=$(jq -r '.data.current // "0"' batterydata.json)
  sensor_data["battery_dischargevolt"]=$(jq -r '.data.dischargeVolt // "0"' batterydata.json)
  sensor_data["battery_power"]=$(jq -r '.data.power // "0"' batterydata.json)
  sensor_data["battery_soc"]=$(jq -r '.data.soc // "0"' batterydata.json)
  sensor_data["battery_temperature"]=$(jq -r '.data.temp // "0"' batterydata.json)
  sensor_data["battery_type"]=$(jq -r '.data.type // "Unknown"' batterydata.json)
  sensor_data["battery_voltage"]=$(jq -r '.data.voltage // "0"' batterydata.json)

  # Battery 1
  sensor_data["battery1_voltage"]=$(jq -r '.data.batteryVolt1 // "0"' batterydata.json)
  sensor_data["battery1_current"]=$(jq -r '.data.batteryCurrent1 // "0"' batterydata.json)
  sensor_data["battery1_power"]=$(jq -r '.data.batteryPower1 // "0"' batterydata.json)
  sensor_data["battery1_soc"]=$(jq -r '.data.batterySoc1 // "0"' batterydata.json)
  sensor_data["battery1_temperature"]=$(jq -r '.data.batteryTemp1 // "0"' batterydata.json)
  sensor_data["battery1_status"]=$(jq -r '.data.status // "0"' batterydata.json)

  # Battery 2
  sensor_data["battery2_voltage"]=$(jq -r '.data.batteryVolt2 // "0"' batterydata.json)
  sensor_data["battery2_current"]=$(jq -r '.data.batteryCurrent2 // "0"' batterydata.json)
  sensor_data["battery2_chargevolt"]=$(jq -r '.data.chargeVolt2 // "0"' batterydata.json)
  sensor_data["battery_dischargevolt2"]=$(jq -r '.data.dischargeVolt2 // "0"' batterydata.json)
  sensor_data["battery2_power"]=$(jq -r '.data.batteryPower2 // "0"' batterydata.json)
  sensor_data["battery2_soc"]=$(jq -r '.data.batterySoc2 // "0"' batterydata.json)
  sensor_data["battery2_temperature"]=$(jq -r '.data.batteryTemp2 // "0"' batterydata.json)
  sensor_data["battery2_status"]=$(jq -r '.data.batteryStatus2 // "0"' batterydata.json)

  # Daily energy figures
  sensor_data["day_battery_charge"]=$(jq -r '.data.etodayChg // "0"' batterydata.json)
  sensor_data["day_battery_discharge"]=$(jq -r '.data.etodayDischg // "0"' batterydata.json)
  sensor_data["day_grid_export"]=$(jq -r '.data.etodayTo // "0"' griddata.json)
  sensor_data["day_grid_import"]=$(jq -r '.data.etodayFrom // "0"' griddata.json)
  sensor_data["day_load_energy"]=$(jq -r '.data.dailyUsed // "0"' loaddata.json)
  sensor_data["day_pv_energy"]=$(jq -r '.data.etoday // "0"' pvindata.json)

  # Grid data
  sensor_data["grid_connected_status"]=$(jq -r '.data.status // "0"' griddata.json)
  sensor_data["grid_frequency"]=$(jq -r '.data.fac // "0"' griddata.json)
  sensor_data["grid_power"]=$(jq -r '.data.vip[0].power // "0"' griddata.json)
  sensor_data["grid_voltage"]=$(jq -r '.data.vip[0].volt // "0"' griddata.json)
  sensor_data["grid_current"]=$(jq -r '.data.vip[0].current // "0"' griddata.json)
  sensor_data["grid_power1"]=$(jq -r '.data.vip[1].power // "0"' griddata.json)
  sensor_data["grid_voltage1"]=$(jq -r '.data.vip[1].volt // "0"' griddata.json)
  sensor_data["grid_current1"]=$(jq -r '.data.vip[1].current // "0"' griddata.json)
  sensor_data["grid_power2"]=$(jq -r '.data.vip[2].power // "0"' griddata.json)
  sensor_data["grid_voltage2"]=$(jq -r '.data.vip[2].volt // "0"' griddata.json)
  sensor_data["grid_current2"]=$(jq -r '.data.vip[2].current // "0"' griddata.json)

  # Inverter data
  sensor_data["inverter_frequency"]=$(jq -r '.data.fac // "0"' outputdata.json)
  sensor_data["inverter_current"]=$(jq -r '.data.vip[0].current // "0"' outputdata.json)
  sensor_data["inverter_power"]=$(jq -r '.data.vip[0].power // "0"' outputdata.json)
  sensor_data["inverter_voltage"]=$(jq -r '.data.vip[0].volt // "0"' outputdata.json)
  sensor_data["inverter_current1"]=$(jq -r '.data.vip[1].current // "0"' outputdata.json)
  sensor_data["inverter_power1"]=$(jq -r '.data.vip[1].power // "0"' outputdata.json)
  sensor_data["inverter_voltage1"]=$(jq -r '.data.vip[1].volt // "0"' outputdata.json)
  sensor_data["inverter_current2"]=$(jq -r '.data.vip[2].current // "0"' outputdata.json)
  sensor_data["inverter_power2"]=$(jq -r '.data.vip[2].power // "0"' outputdata.json)
  sensor_data["inverter_voltage2"]=$(jq -r '.data.vip[2].volt // "0"' outputdata.json)

  # Load data
  sensor_data["load_frequency"]=$(jq -r '.data.loadFac // "0"' loaddata.json)
  sensor_data["load_voltage"]=$(jq -r '.data.vip[0].volt // "0"' loaddata.json)
  sensor_data["load_voltage1"]=$(jq -r '.data.vip[1].volt // "0"' loaddata.json)
  sensor_data["load_voltage2"]=$(jq -r '.data.vip[2].volt // "0"' loaddata.json)
  sensor_data["load_current"]=$(jq -r '.data.vip[0].current // "0"' loaddata.json)
  sensor_data["load_current1"]=$(jq -r '.data.vip[1].current // "0"' loaddata.json)
  sensor_data["load_current2"]=$(jq -r '.data.vip[2].current // "0"' loaddata.json)
  sensor_data["load_power"]=$(jq -r '.data.vip[0].power // "0"' loaddata.json)
  sensor_data["load_power1"]=$(jq -r '.data.vip[1].power // "0"' loaddata.json)
  sensor_data["load_power2"]=$(jq -r '.data.vip[2].power // "0"' loaddata.json)
  sensor_data["load_upsPowerL1"]=$(jq -r '.data.upsPowerL1 // "0"' loaddata.json)
  sensor_data["load_upsPowerL2"]=$(jq -r '.data.upsPowerL2 // "0"' loaddata.json)
  sensor_data["load_upsPowerL3"]=$(jq -r '.data.upsPowerL3 // "0"' loaddata.json)
  sensor_data["load_upsPowerTotal"]=$(jq -r '.data.upsPowerTotal // "0"' loaddata.json)
  sensor_data["load_totalpower"]=$(jq -r '.data.totalPower // "0"' loaddata.json)

  # Solar data
  sensor_data["pv1_current"]=$(jq -r '.data.pvIV[0].ipv // "0"' pvindata.json)
  sensor_data["pv1_power"]=$(jq -r '.data.pvIV[0].ppv // "0"' pvindata.json)
  sensor_data["pv1_voltage"]=$(jq -r '.data.pvIV[0].vpv // "0"' pvindata.json)
  sensor_data["pv2_current"]=$(jq -r '.data.pvIV[1].ipv // "0"' pvindata.json)
  sensor_data["pv2_power"]=$(jq -r '.data.pvIV[1].ppv // "0"' pvindata.json)
  sensor_data["pv2_voltage"]=$(jq -r '.data.pvIV[1].vpv // "0"' pvindata.json)
  sensor_data["pv3_current"]=$(jq -r '.data.pvIV[2].ipv // "0"' pvindata.json)
  sensor_data["pv3_power"]=$(jq -r '.data.pvIV[2].ppv // "0"' pvindata.json)
  sensor_data["pv3_voltage"]=$(jq -r '.data.pvIV[2].vpv // "0"' pvindata.json)
  sensor_data["pv4_current"]=$(jq -r '.data.pvIV[3].ipv // "0"' pvindata.json)
  sensor_data["pv4_power"]=$(jq -r '.data.pvIV[3].ppv // "0"' pvindata.json)
  sensor_data["pv4_voltage"]=$(jq -r '.data.pvIV[3].vpv // "0"' pvindata.json)
  sensor_data["overall_state"]=$(jq -r '.data.runStatus // "Unknown"' inverterinfo.json)

  # Settings/Program data
  sensor_data["prog1_time"]=$(jq -r '.data.sellTime1 // ""' settings.json)
  sensor_data["prog2_time"]=$(jq -r '.data.sellTime2 // ""' settings.json)
  sensor_data["prog3_time"]=$(jq -r '.data.sellTime3 // ""' settings.json)
  sensor_data["prog4_time"]=$(jq -r '.data.sellTime4 // ""' settings.json)
  sensor_data["prog5_time"]=$(jq -r '.data.sellTime5 // ""' settings.json)
  sensor_data["prog6_time"]=$(jq -r '.data.sellTime6 // ""' settings.json)
  sensor_data["prog1_charge"]=$(jq -r '.data.time1on // ""' settings.json)
  sensor_data["prog2_charge"]=$(jq -r '.data.time2on // ""' settings.json)
  sensor_data["prog3_charge"]=$(jq -r '.data.time3on // ""' settings.json)
  sensor_data["prog4_charge"]=$(jq -r '.data.time4on // ""' settings.json)
  sensor_data["prog5_charge"]=$(jq -r '.data.time5on // ""' settings.json)
  sensor_data["prog6_charge"]=$(jq -r '.data.time6on // ""' settings.json)
  sensor_data["prog1_capacity"]=$(jq -r '.data.cap1 // "0"' settings.json)
  sensor_data["prog2_capacity"]=$(jq -r '.data.cap2 // "0"' settings.json)
  sensor_data["prog3_capacity"]=$(jq -r '.data.cap3 // "0"' settings.json)
  sensor_data["prog4_capacity"]=$(jq -r '.data.cap4 // "0"' settings.json)
  sensor_data["prog5_capacity"]=$(jq -r '.data.cap5 // "0"' settings.json)
  sensor_data["prog6_capacity"]=$(jq -r '.data.cap6 // "0"' settings.json)
  sensor_data["battery_shutdown_cap"]=$(jq -r '.data.batteryShutdownCap // "0"' settings.json)
  sensor_data["use_timer"]=$(jq -r '.data.peakAndVallery // "0"' settings.json)
  sensor_data["priority_load"]=$(jq -r '.data.energyMode // "0"' settings.json)

  # Temperature data
  sensor_data["dc_temp"]=$(jq -r '.data.infos[0].records[-1].value // "0"' dcactemp.json)
  sensor_data["ac_temp"]=$(jq -r '.data.infos[1].records[-1].value // "0"' dcactemp.json)

  # Dump all data if verbose logging is enabled
  if [ "$ENABLE_VERBOSE_LOG" == "true" ]; then
    echo "Raw data per file"
    echo ------------------------------------------------------------------------------
    echo "pvindata.json"
    cat pvindata.json
    echo ------------------------------------------------------------------------------
    echo "griddata.json"
    cat griddata.json
    echo ------------------------------------------------------------------------------
    echo "loaddata.json"
    cat loaddata.json
    echo ------------------------------------------------------------------------------
    echo "batterydata.json"
    cat batterydata.json
    echo ------------------------------------------------------------------------------
    echo "outputdata.json"
    cat outputdata.json
    echo ------------------------------------------------------------------------------
    echo "dcactemp.json"
    cat dcactemp.json
    echo ------------------------------------------------------------------------------
    echo "inverterinfo.json"
    cat inverterinfo.json
    echo ------------------------------------------------------------------------------
    echo "settings.json"
    cat settings.json
    echo ------------------------------------------------------------------------------
    echo "Values to send. If ALL values are NULL then something went wrong:"

    # Print all sensor data
    for key in "${!sensor_data[@]}"; do
      echo "$key: ${sensor_data[$key]}"
    done
    echo ------------------------------------------------------------------------------
  fi

  # We don't need to return anything as we're using the global sensor_data array
  return 0
}

# Get a specific sensor value
get_sensor_value() {
  local sensor_id=$1
  echo "${sensor_data[$sensor_id]}"
}

# Check if a sensor has valid data
is_valid_sensor_value() {
  local sensor_id=$1
  local value="${sensor_data[$sensor_id]}"

  if [ "$value" == "null" ] || [ -z "$value" ]; then
    return 1
  else
    return 0
  fi
}
