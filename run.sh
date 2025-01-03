#!/usr/bin/with-contenv bashio
set +e
while :
do
CONFIG_PATH=/data/options.json

sunsynk_user=""
sunsynk_pass=""
sunsynk_serial=""
HA_LongLiveToken=""
Home_Assistant_IP=""

sunsynk_user="$(bashio::config 'sunsynk_user')"
sunsynk_pass="$(bashio::config 'sunsynk_pass')"
sunsynk_serial="$(bashio::config 'sunsynk_serial')"
HA_LongLiveToken="$(bashio::config 'HA_LongLiveToken')"
Home_Assistant_IP="$(bashio::config 'Home_Assistant_IP')"
Home_Assistant_PORT="$(bashio::config 'Home_Assistant_PORT')"
Refresh_rate="$(bashio::config 'Refresh_rate')"
Enable_HTTPS="$(bashio::config 'Enable_HTTPS')"
Enable_Verbose_Log="$(bashio::config 'Enable_Verbose_Log')"
Settings_Helper_Entity="$(bashio::config 'Settings_Helper_Entity')"

VarCurrentDate=$(date +%Y-%m-%d)

if [ $Enable_HTTPS == "true" ]; then HTTP_Connect_Type="https"; else HTTP_Connect_Type="http"; fi;

ServerAPIBearerToken=""
SolarInputData=""
dt=$(date '+%d/%m/%Y %H:%M:%S')

echo ""
echo ------------------------------------------------------------------------------
echo -- SolarSynk - Log
echo ------------------------------------------------------------------------------
echo "Script execution date & time:" $dt
echo "Verbose logging is set to:" $Enable_Verbose_Log
echo "HTTP Connect type:" $HTTP_Connect_Type
#echo $sunsynk_user
#echo $sunsynk_pass
#echo $sunsynk_serial
#echo $HA_LongLiveToken

echo "Getting bearer token from solar service provider's API."
ServerAPIBearerToken=$(curl -s -k -X POST -H "Content-Type: application/json" https://api.sunsynk.net/oauth/token -d '{"areaCode": "sunsynk","client_id": "csp-web","grant_type": "password","password": "'"$sunsynk_pass"'","source": "sunsynk","username": "'"$sunsynk_user"'"}' | jq -r '.data.access_token')

echo "Bearer Token length:" ${#ServerAPIBearerToken}

#BOF Check if Token is valid
if [  -z "$ServerAPIBearerToken"  ]
then
	echo "****Token could not be retrieved due to the following possibilities****"
	echo "Incorrect setup, please check the configuration tab."
	echo "Either this HA instance cannot reach Sunsynk.net due to network problems or the Sunsynk server is down."
	echo "The Sunsynk server admins are rejecting due to too frequent connection requests."
	echo ""
	echo "This Script will not continue to run but will continue to loop. No values were updated."
	echo "Dumping Curl output for more information below."
	ServerAPIBearerToken=$(curl -v -s -X POST -H "Content-Type: application/json" https://api.sunsynk.net/oauth/token -d '{"areaCode": "sunsynk","client_id": "csp-web","grant_type": "password","password": "'"$sunsynk_pass"'","source": "sunsynk","username": "'"$sunsynk_user"'"}' | jq -r '.')
	echo $ServerAPIBearerToken
	
else


#echo "Sunsynk Server API Token:" $ServerAPIBearerToken
echo "Sunsynk Server API Token: Hidden for security reasons"
echo "Refresh rate set to:" $Refresh_rate "seconds."
echo "Note: Setting the refresh rate lower than the update rate of SunSynk is pointless and will just result in wasted disk space."


IFS=";"
for inverter_serial in $sunsynk_serial
do
# BOF Serial Number Loop

echo ""
echo "Fetching data for serial:" $inverter_serial
echo "Cleaning up old data."
rm -rf pvindata.json
rm -rf griddata.json
rm -rf loaddata.json
rm -rf batterydata.json
rm -rf outputdata.json
rm -rf dcactemp.json
rm -rf inverterinfo.json

echo "Please wait while curl is fetching input, grid, load, battery & output data..."
curl -s -k -X GET -H "Content-Type: application/json" -H "authorization: Bearer $ServerAPIBearerToken" https://api.sunsynk.net/api/v1/inverter/$inverter_serial/realtime/input -o "pvindata.json"
curl -s -k -X GET -H "Content-Type: application/json" -H "authorization: Bearer $ServerAPIBearerToken" https://api.sunsynk.net/api/v1/inverter/grid/$inverter_serial/realtime?sn=$inverter_serial -o "griddata.json"
curl -s -k -X GET -H "Content-Type: application/json" -H "authorization: Bearer $ServerAPIBearerToken" https://api.sunsynk.net/api/v1/inverter/load/$inverter_serial/realtime?sn=$inverter_serial -o "loaddata.json"
curl -s -k -X GET -H "Content-Type: application/json" -H "authorization: Bearer $ServerAPIBearerToken" "https://api.sunsynk.net/api/v1/inverter/battery/$inverter_serial/realtime?sn=$inverter_serial&lan=en" -o "batterydata.json"
curl -s -k -X GET -H "Content-Type: application/json" -H "authorization: Bearer $ServerAPIBearerToken" https://api.sunsynk.net/api/v1/inverter/$inverter_serial/realtime/output -o "outputdata.json"
curl -s -k -X GET -H "Content-Type: application/json" -H "authorization: Bearer $ServerAPIBearerToken" "https://api.sunsynk.net/api/v1/inverter/$inverter_serial/output/day?lan=en&date=$VarCurrentDate&column=dc_temp,igbt_temp" -o "dcactemp.json"
curl -s -k -X GET -H "Content-Type: application/json" -H "authorization: Bearer $ServerAPIBearerToken" https://api.sunsynk.net/api/v1/inverter/$inverter_serial  -o "inverterinfo.json"
curl -s -k -X GET -H "Content-Type: application/json" -H "authorization: Bearer $ServerAPIBearerToken" https://api.sunsynk.net/api/v1/common/setting/$inverter_serial/read  -o "settings.json"




inverterinfo_brand=$(jq -r '.data.brand' inverterinfo.json)
inverterinfo_status=$(jq -r '.data.status' inverterinfo.json)
inverterinfo_runstatus=$(jq -r '.data.runStatus' inverterinfo.json)
inverterinfo_ratepower=$(jq -r '.data.ratePower' inverterinfo.json)
inverterinfo_plantid=$(jq -r '.data.plant.id' inverterinfo.json)
inverterinfo_plantname=$(jq -r '.data.plant.name' inverterinfo.json)
inverterinfo_serial=$(jq -r '.data.sn' inverterinfo.json)

echo ------------------------------------------------------------------------------
echo "Inverter Information"
echo "Brand:" $inverterinfo_brand
echo "Status:" $inverterinfo_runstatus
echo "Max Watts:" $inverterinfo_ratepower
echo "Plant ID:" $inverterinfo_plantid
echo "Plant Name:" $inverterinfo_plantname
echo "Inverter S/N:" $inverterinfo_serial
echo ------------------------------------------------------------------------------

#Unused
#curl -s -k -X GET -H "Content-Type: application/json" -H "authorization: Bearer $ServerAPIBearerToken" https://api.sunsynk.net/api/v1/inverter/$sunsynk_serial/flow -o "flowdata.json"
# Read Settings https://api.sunsynk.net/api/v1/common/setting/$sunsynk_serial/read
# Save Settings https://api.sunsynk.net/api/v1/common/setting/$sunsynk_serial/set


echo "Data fetched for serial $inverter_serial. Enable verbose logging to see more information."
#Total Battery
battery_capacity=$(jq -r '.data.capacity' batterydata.json); if [ $battery_capacity == "null" ]; then battery_capacity="0"; fi;
battery_chargevolt=$(jq -r '.data.chargeVolt' batterydata.json); if [ $battery_chargevolt == "null" ]; then battery_chargevolt="0"; fi;
battery_current=$(jq -r '.data.current' batterydata.json); if [ $battery_current == "null" ]; then battery_current="0"; fi;
battery_dischargevolt=$(jq -r '.data.dischargeVolt' batterydata.json); if [ $battery_dischargevolt == "null" ]; then battery_dischargevolt="0"; fi;
battery_power=$(jq -r '.data.power' batterydata.json); if [ $battery_power == "null" ]; then battery_power="0"; fi;
battery_soc=$(jq -r '.data.soc' batterydata.json); if [ $battery_soc == "null" ]; then battery_soc="0"; fi;
battery_temperature=$(jq -r '.data.temp' batterydata.json); if [ $battery_temperature == "null" ]; then battery_temperature="0"; fi;
battery_type=$(jq -r '.data.type' batterydata.json); if [ $battery_type == "null" ]; then battery_type="0"; fi;
battery_voltage=$(jq -r '.data.voltage' batterydata.json); if [ $battery_voltage == "null" ]; then battery_voltage="0"; fi;
#Battery 1
battery1_voltage=$(jq -r '.data.batteryVolt1' batterydata.json); if [ $battery1_voltage == "null" ]; then battery1_voltage="0"; fi;
battery1_current=$(jq -r '.data.batteryCurrent1' batterydata.json); if [ $battery1_current == "null" ]; then battery1_current="0"; fi;
battery1_power=$(jq -r '.data.batteryPower1' batterydata.json); if [ $battery1_power == "null" ]; then battery1_power="0"; fi;
battery1_soc=$(jq -r '.data.batterySoc1' batterydata.json); if [ $battery1_soc == "null" ]; then battery1_soc="0"; fi;
battery1_temperature=$(jq -r '.data.batteryTemp1' batterydata.json); if [ $battery1_temperature == "null" ]; then battery1_temperature="0"; fi;
battery1_status=$(jq -r '.data.status' batterydata.json); if [ $battery1_status == "null" ]; then battery1_status="0"; fi;
#Battery 2
battery2_voltage=$(jq -r '.data.batteryVolt2' batterydata.json); if [ $battery2_voltage == "null" ]; then battery2_voltage="0"; fi;
battery2_current=$(jq -r '.data.batteryCurrent2' batterydata.json); if [ $battery2_current == "null" ]; then battery2_current="0"; fi;
battery2_chargevolt=$(jq -r '.data.chargeVolt2' batterydata.json); if [ $battery2_chargevolt == "null" ]; then battery2_chargevolt="0"; fi;
battery_dischargevolt2=$(jq -r '.data.dischargeVolt2' batterydata.json); if [ $battery_dischargevolt2 == "null" ]; then battery_dischargevolt2="0"; fi;
battery2_power=$(jq -r '.data.batteryPower2' batterydata.json); if [ $battery2_power == "null" ]; then battery2_power="0"; fi;
battery2_soc=$(jq -r '.data.batterySoc2' batterydata.json); if [ $battery_capacity == "null" ]; then battery_capacity="0"; fi;
battery2_temperature=$(jq -r '.data.batteryTemp2' batterydata.json); if [ $battery2_temperature == "null" ]; then battery2_temperature="0"; fi;
battery2_status=$(jq -r '.data.batteryStatus2' batterydata.json); if [ $battery2_status == "null" ]; then battery2_status="0"; fi;


day_battery_charge=$(jq -r '.data.etodayChg' batterydata.json); if [ $day_battery_charge == "null" ]; then day_battery_charge="0"; fi;
day_battery_discharge=$(jq -r '.data.etodayDischg' batterydata.json); if [ $day_battery_discharge == "null" ]; then day_battery_discharge="0"; fi;
day_grid_export=$(jq -r '.data.etodayTo' griddata.json); if [ $day_grid_export == "null" ]; then day_grid_export="0"; fi;
day_grid_import=$(jq -r '.data.etodayFrom' griddata.json); if [ $day_grid_import == "null" ]; then day_grid_import="0"; fi;
day_load_energy=$(jq -r '.data.dailyUsed' loaddata.json); if [ $day_load_energy == "null" ]; then day_load_energy="0"; fi;
day_pv_energy=$(jq -r '.data.etoday' pvindata.json); if [ $day_pv_energy == "null" ]; then day_pv_energy="0"; fi;
grid_connected_status=$(jq -r '.data.status' griddata.json); if [ $grid_connected_status == "null" ]; then grid_connected_status="0"; fi;
grid_frequency=$(jq -r '.data.fac' griddata.json); if [ $grid_frequency == "null" ]; then grid_frequency="0"; fi;

grid_power=$(jq -r '.data.vip[0].power' griddata.json); if [ $grid_power == "null" ]; then grid_power="0"; fi;
grid_voltage=$(jq -r '.data.vip[0].volt' griddata.json); if [ $grid_voltage == "null" ]; then grid_voltage="0"; fi;
grid_current=$(jq -r '.data.vip[0].current' griddata.json); if [ $grid_current == "null" ]; then grid_current="0"; fi;

grid_power1=$(jq -r '.data.vip[1].power' griddata.json); if [ $grid_power1 == "null" ]; then grid_power1="0"; fi;
grid_voltage1=$(jq -r '.data.vip[1].volt' griddata.json); if [ $grid_voltage1 == "null" ]; then grid_voltage1="0"; fi;
grid_current1=$(jq -r '.data.vip[1].current' griddata.json); if [ $grid_current1 == "null" ]; then grid_current1="0"; fi;

grid_power2=$(jq -r '.data.vip[2].power' griddata.json); if [ $grid_power2 == "null" ]; then grid_power2="0"; fi;
grid_voltage2=$(jq -r '.data.vip[2].volt' griddata.json); if [ $grid_voltage2 == "null" ]; then grid_voltage2="0"; fi;
grid_current2=$(jq -r '.data.vip[2].current' griddata.json); if [ $grid_current2 == "null" ]; then grid_current2="0"; fi;

#Inverter
inverter_frequency=$(jq -r '.data.fac' outputdata.json); if [ $inverter_frequency == "null" ]; then inverter_frequency="0"; fi;

inverter_current=$(jq -r '.data.vip[0].current' outputdata.json); if [ $inverter_current == "null" ]; then inverter_current="0"; fi;
inverter_power=$(jq -r '.data.vip[0].power' outputdata.json); if [ $inverter_power == "null" ]; then inverter_power="0"; fi;
inverter_voltage=$(jq -r '.data.vip[0].volt' outputdata.json); if [ $inverter_voltage == "null" ]; then inverter_voltage="0"; fi;

inverter_current1=$(jq -r '.data.vip[1].current' outputdata.json); if [ $inverter_current1 == "null" ]; then inverter_current1="0"; fi;
inverter_power1=$(jq -r '.data.vip[1].power' outputdata.json); if [ $inverter_power1 == "null" ]; then inverter_power1="0"; fi;
inverter_voltage1=$(jq -r '.data.vip[1].volt' outputdata.json); if [ $inverter_voltage1 == "null" ]; then inverter_voltage1="0"; fi;

inverter_current2=$(jq -r '.data.vip[2].current' outputdata.json); if [ $inverter_current2 == "null" ]; then inverter_current2="0"; fi;
inverter_power2=$(jq -r '.data.vip[2].power' outputdata.json); if [ $inverter_power2 == "null" ]; then inverter_power2="0"; fi;
inverter_voltage2=$(jq -r '.data.vip[2].volt' outputdata.json); if [ $inverter_voltage2 == "null" ]; then inverter_voltage2="0"; fi;

#BOF Load Data
load_frequency=$(jq -r '.data.loadFac' loaddata.json); if [ $load_frequency == "null" ]; then load_frequency="0"; fi;

load_voltage=$(jq -r '.data.vip[0].volt' loaddata.json); if [ $load_voltage == "null" ]; then load_voltage="0"; fi;
load_voltage1=$(jq -r '.data.vip[1].volt' loaddata.json); if [ $load_voltage1 == "null" ]; then load_voltage1="0"; fi;
load_voltage2=$(jq -r '.data.vip[2].volt' loaddata.json); if [ $load_voltage2 == "null" ]; then load_voltage2="0"; fi;

load_current=$(jq -r '.data.vip[0].current' loaddata.json); if [ $load_current == "null" ]; then load_current="0"; fi;
load_current1=$(jq -r '.data.vip[1].current' loaddata.json); if [ $load_current1 == "null" ]; then load_current1="0"; fi;
load_current2=$(jq -r '.data.vip[2].current' loaddata.json); if [ $load_current2 == "null" ]; then load_current2="0"; fi;

load_power=$(jq -r '.data.vip[0].power' loaddata.json); if [ $load_power == "null" ]; then load_power="0"; fi;
load_power1=$(jq -r '.data.vip[1].power' loaddata.json); if [ $load_power1 == "null" ]; then load_power1="0"; fi;
load_power2=$(jq -r '.data.vip[2].power' loaddata.json); if [ $load_power2 == "null" ]; then load_power2="0"; fi;

load_upsPowerL1=$(jq -r '.data.upsPowerL1' loaddata.json); if [ $load_upsPowerL1 == "null" ]; then load_upsPowerL1="0"; fi;
load_upsPowerL2=$(jq -r '.data.upsPowerL2' loaddata.json); if [ $load_upsPowerL2 == "null" ]; then load_upsPowerL2="0"; fi;
load_upsPowerL3=$(jq -r '.data.upsPowerL3' loaddata.json); if [ $load_upsPowerL3 == "null" ]; then load_upsPowerL3="0"; fi;
load_upsPowerTotal=$(jq -r '.data.upsPowerTotal' loaddata.json); if [ $load_upsPowerTotal == "null" ]; then load_upsPowerTotal="0"; fi;

load_totalpower=$(jq -r '.data.totalPower' loaddata.json); if [ $load_totalpower == "null" ]; then load_totalpower="0"; fi;
# EOF Load Data
pv1_current=$(jq -r '.data.pvIV[0].ipv' pvindata.json); if [ $pv1_current == "null" ]; then pv1_current="0"; fi;
pv1_power=$(jq -r '.data.pvIV[0].ppv' pvindata.json); if [ $pv1_power == "null" ]; then pv1_power="0"; fi;
pv1_voltage=$(jq -r '.data.pvIV[0].vpv' pvindata.json); if [ $pv1_voltage == "null" ]; then pv1_voltage="0"; fi;
pv2_current=$(jq -r '.data.pvIV[1].ipv' pvindata.json); if [ $pv2_current == "null" ]; then pv2_current="0"; fi;
pv2_power=$(jq -r '.data.pvIV[1].ppv' pvindata.json); if [ $pv2_power == "null" ]; then pv2_power="0"; fi;
pv2_voltage=$(jq -r '.data.pvIV[1].vpv' pvindata.json); if [ $pv2_voltage == "null" ]; then pv2_voltage="0"; fi;

pv3_current=$(jq -r '.data.pvIV[2].ipv' pvindata.json); if [ $pv3_current == "null" ]; then pv3_current="0"; fi;
pv3_power=$(jq -r '.data.pvIV[2].ppv' pvindata.json); if [ $pv3_power == "null" ]; then pv3_power="0"; fi;
pv3_voltage=$(jq -r '.data.pvIV[2].vpv' pvindata.json); if [ $pv3_voltage == "null" ]; then pv3_voltage="0"; fi;
pv4_current=$(jq -r '.data.pvIV[3].ipv' pvindata.json); if [ $pv4_current == "null" ]; then pv4_current="0"; fi;
pv4_power=$(jq -r '.data.pvIV[3].ppv' pvindata.json); if [ $pv4_power == "null" ]; then pv4_power="0"; fi;
pv4_voltage=$(jq -r '.data.pvIV[3].vpv' pvindata.json); if [ $pv4_voltage == "null" ]; then pv4_voltage="0"; fi;

overall_state=$(jq -r '.data.runStatus' inverterinfo.json); if [ $overall_state == "null" ]; then overall_state="0"; fi;

#Settings Sensors
prog1_time=$(jq -r '.data.sellTime1' settings.json); 
prog2_time=$(jq -r '.data.sellTime2' settings.json); 
prog3_time=$(jq -r '.data.sellTime3' settings.json); 
prog4_time=$(jq -r '.data.sellTime4' settings.json); 
prog5_time=$(jq -r '.data.sellTime5' settings.json); 
prog6_time=$(jq -r '.data.sellTime6' settings.json); 

prog1_charge=$(jq -r '.data.time1on' settings.json); 
prog2_charge=$(jq -r '.data.time2on' settings.json);
prog3_charge=$(jq -r '.data.time3on' settings.json);
prog4_charge=$(jq -r '.data.time4on' settings.json);
prog5_charge=$(jq -r '.data.time5on' settings.json);
prog6_charge=$(jq -r '.data.time6on' settings.json);

prog1_capacity=$(jq -r '.data.cap1' settings.json); 
prog2_capacity=$(jq -r '.data.cap2' settings.json); 
prog3_capacity=$(jq -r '.data.cap3' settings.json); 
prog4_capacity=$(jq -r '.data.cap4' settings.json); 
prog5_capacity=$(jq -r '.data.cap5' settings.json); 
prog6_capacity=$(jq -r '.data.cap6' settings.json); 

battery_shutdown_cap=$(jq -r '.data.batteryShutdownCap' settings.json); 
use_timer=$(jq -r '.data.peakAndVallery' settings.json); 
priority_load=$(jq -r '.data.energyMode' settings.json); 

dc_temp=$(jq -r '.data.infos[0].records[-1].value' dcactemp.json)
ac_temp=$(jq -r '.data.infos[1].records[-1].value' dcactemp.json)



EntityLogOutput="-o tmpcurllog.json"
if [ $Enable_Verbose_Log == "true" ]
then
EntityLogOutput=""
echo "If ALL values are NULL then something went wrong."
# Dump of all values
echo "battery_capacity" $battery_capacity
echo "battery_chargevolt" $battery_chargevolt
echo "battery_current" $battery_current
echo "battery_dischargevolt" $battery_dischargevolt
echo "battery_power" $battery_power
echo "battery_soc" $battery_soc
echo "battery_temperature" $battery_temperature
echo "battery_type" $battery_type
echo "battery_voltage" $battery_voltage
echo "day_battery_charge" $day_battery_charge
echo "day_battery_discharge" $day_battery_discharge
#Battery 1
echo "battery1_voltage" $battery1_voltage
echo "battery1_current" $battery1_current
echo "battery1_power" $battery1_power
echo "battery1_soc" $battery1_soc
echo "battery1_temperature" $battery1_temperature
echo "battery1_status" $battery1_status
#Battery 2
echo "battery2_voltage" $battery2_voltage
echo "battery2_current" $battery2_current
echo "battery_dischargevolt2" $battery_dischargevolt2
echo "battery2_power" $battery2_power
echo "battery2_soc" $battery2_soc
echo "battery2_temperature" $battery2_temperature
echo "battery2_status" $battery2_status

echo "day_grid_export" $day_grid_export
echo "day_grid_import" $day_grid_import
echo "day_load_energy" $day_load_energy
echo "day_pv_energy" $day_pv_energy
echo "grid_connected_status" $grid_connected_status
echo "grid_frequency" $grid_frequency
echo "grid_power" $grid_power
echo "grid_voltage" $grid_voltage
echo "grid_current" $grid_current

echo "grid_power1" $grid_power1
echo "grid_voltage1" $grid_voltage1
echo "grid_current1" $grid_current1

echo "grid_power2" $grid_power2
echo "grid_voltage2" $grid_voltage2
echo "grid_current2" $grid_current2


echo "inverter_frequency" $inverter_frequency

echo "inverter_power" $inverter_power
echo "inverter_current" $inverter_current
echo "inverter_voltage" $inverter_voltage

echo "inverter_power1" $inverter_power1
echo "inverter_voltage1" $inverter_voltage1
echo "inverter_current1" $inverter_current1

echo "inverter_power2" $inverter_power2
echo "inverter_voltage2" $inverter_voltage2
echo "inverter_current2" $inverter_current2


#Load
echo "load_frequency" $load_frequency

echo "load_current" $load_current
echo "load_power" $load_power
echo "load_voltage" $load_voltage
echo "load_current1" $load_current
echo "load_power1" $load_power
echo "load_voltage1" $load_voltage
echo "load_current2" $load_current
echo "load_power2" $load_power
echo "load_voltage2" $load_voltage

echo "load_totalpower" $load_totalpower


echo "load_upsPowerL1" $load_upsPowerL1
echo "load_upsPowerL2" $load_upsPowerL2
echo "load_upsPowerL3" $load_upsPowerL3
echo "load_upsPowerTotal" $load_upsPowerTotal



echo "pv1_current" $pv1_current
echo "pv1_power" $pv1_power
echo "pv1_voltage" $pv1_voltage
echo "pv2_current" $pv2_current
echo "pv2_power" $pv2_power
echo "pv2_voltage" $pv2_voltage

echo "pv3_current" $pv3_current
echo "pv3_power" $pv3_power
echo "pv3_voltage" $pv3_voltage
echo "pv4_current" $pv4_current
echo "pv4_power" $pv4_power
echo "pv4_voltage" $pv4_voltage

echo "overall_state" $overall_state
#Settings Sensors
echo "prog1_time:" $prog1_time
echo "prog2_time:" $prog2_time
echo "prog3_time:" $prog3_time
echo "prog4_time:" $prog4_time
echo "prog5_time:" $prog5_time
echo "prog6_time:" $prog6_time

echo "prog1_charge:" $prog1_charge
echo "prog2_charge:" $prog2_charge
echo "prog3_charge:" $prog3_charge
echo "prog4_charge:" $prog4_charge
echo "prog5_charge:" $prog5_charge
echo "prog6_charge:" $prog6_charge

echo "prog1_capacity:" $prog1_capacity
echo "prog2_capacity:" $prog2_capacity
echo "prog3_capacity:" $prog3_capacity
echo "prog4_capacity:" $prog4_capacity
echo "prog5_capacity:" $prog5_capacity
echo "prog6_capacity:" $prog6_capacity

echo "battery_shutdown_cap:" $battery_shutdown_cap
echo "use_timer:" $use_timer
echo "priority_load:" $priority_load
#Temperature
echo "dc_temp:" $dc_temp
echo "ac_temp:" $ac_temp


echo ------------------------------------------------------------------------------
echo "Attempting to update the following sensor entities"
echo "Sending to" $HTTP_Connect_Type"://"$Home_Assistant_IP":"$Home_Assistant_PORT
echo ------------------------------------------------------------------------------
fi


#Battery Stuff
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"unit_of_measurement": "Ah", "friendly_name": "Battery Capacity"}, "state": "'"$battery_capacity"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_capacity $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Battery Charge Voltage"}, "state": "'"$battery_chargevolt"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_chargevolt $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "Battery Current"}, "state": "'"$battery_current"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_current $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Battery Discharge Voltage"}, "state": "'"$battery_dischargevolt"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_dischargevolt $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Battery Power"}, "state": "'"$battery_power"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_power $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power_tor", "state_class":"measurement", "unit_of_measurement": "%", "friendly_name": "Battery SOC"}, "state": "'"$battery_soc"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_soc $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "temperature", "state_class":"measurement", "unit_of_measurement": "°C", "friendly_name": "Battery Temp"}, "state": "'"$battery_temperature"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_temperature $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"unit_of_measurement": "", "friendly_name": "Battery Type"}, "state": "'"$battery_type"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_type $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Battery Voltage"}, "state": "'"$battery_voltage"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_voltage $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "energy", "state_class":"total_increasing", "unit_of_measurement": "kWh", "friendly_name": "Daily Battery Charge"}, "state": "'"$day_battery_charge"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_day_battery_charge $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "energy", "state_class":"total_increasing", "unit_of_measurement": "kWh", "friendly_name": "Daily Battery Discharge"}, "state": "'"$day_battery_discharge"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_day_battery_discharge $EntityLogOutput
#Battery 1
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Battery 1 Charge Voltage"}, "state": "'"$battery_chargevolt"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_chargevolt1 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "Battery 1 Current"}, "state": "'"$battery1_current"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_current1 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Battery 1 Power"}, "state": "'"$battery1_power"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_power1 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power_tor", "state_class":"measurement", "unit_of_measurement": "%", "friendly_name": "Battery 1 SOC"}, "state": "'"$battery1_soc"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_soc1 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "temperature", "state_class":"measurement", "unit_of_measurement": "°C", "friendly_name": "Battery 1 Temp"}, "state": "'"$battery1_temperature"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_temperature1 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"unit_of_measurement": "", "friendly_name": "Battery 1 Status"}, "state": "'"$battery1_status"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery1_status $EntityLogOutput
#Battery 2
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Battery 2 Charge Voltage"}, "state": "'"$battery2_chargevolt"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery1_chargevolt2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "Battery 2 Current"}, "state": "'"$battery2_current"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_current2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Battery Discharge Voltage2"}, "state": "'"$battery_dischargevolt2"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_dischargevolt2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Battery 2 Power"}, "state": "'"$battery2_power"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_power2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power_tor", "state_class":"measurement", "unit_of_measurement": "%", "friendly_name": "Battery 2 SOC"}, "state": "'"$battery2_soc"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_soc2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "temperature", "state_class":"measurement", "unit_of_measurement": "°C", "friendly_name": "Battery 2 Temp"}, "state": "'"$battery2_temperature"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_temperature2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"unit_of_measurement": "", "friendly_name": "Battery 2 Status"}, "state": "'"$battery2_status"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery2_status $EntityLogOutput
#Daily Generation
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "energy", "state_class":"total_increasing", "unit_of_measurement": "kWh", "friendly_name": "Daily Grid Export"}, "state": "'"$day_grid_export"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_day_grid_export $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "energy", "state_class":"total_increasing", "unit_of_measurement": "kWh", "friendly_name": "Daily Grid Import"}, "state": "'"$day_grid_import"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_day_grid_import $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "energy", "state_class":"total_increasing", "unit_of_measurement": "kWh", "friendly_name": "Daily Load Energy"}, "state": "'"$day_load_energy"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_day_load_energy $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "energy", "state_class":"total_increasing", "unit_of_measurement": "kWh", "friendly_name": "Daily PV energy"}, "state": "'"$day_pv_energy"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_day_pv_energy $EntityLogOutput
# Grid
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"unit_of_measurement": "", "friendly_name": "Grid Connection Status"}, "state": "'"$grid_connected_status"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_connected_status $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "frequency", "state_class":"measurement", "unit_of_measurement": "Hz", "friendly_name": "Grid Freq"}, "state": "'"$grid_frequency"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_frequency $EntityLogOutput

curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Grid Power"}, "state": "'"$grid_power"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_power $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Grid Voltage"}, "state": "'"$grid_voltage"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_voltage $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "Grid Current"}, "state": "'"$grid_current"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_current $EntityLogOutput

curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Grid Power1"}, "state": "'"$grid_power1"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_power1 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Grid Voltage1"}, "state": "'"$grid_voltage1"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_voltage1 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "Grid Current1"}, "state": "'"$grid_current1"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_current1 $EntityLogOutput

curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Grid Power2"}, "state": "'"$grid_power2"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_power2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Grid Voltage2"}, "state": "'"$grid_voltage2"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_voltage2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "Grid Current2"}, "state": "'"$grid_current2"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_grid_current2 $EntityLogOutput




#Inverter
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "frequency", "state_class":"measurement", "unit_of_measurement": "Hz", "friendly_name": "Inverter Freq"}, "state": "'"$inverter_frequency"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_inverter_frequency $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "Inverter Current"}, "state": "'"$inverter_current"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_inverter_current $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Inverter Power"}, "state": "'"$inverter_power"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_inverter_power $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Inverter Voltage"}, "state": "'"$inverter_voltage"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_inverter_voltage $EntityLogOutput

curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "Inverter Current1"}, "state": "'"$inverter_current1"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_inverter_current1 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Inverter Power1"}, "state": "'"$inverter_power1"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_inverter_power1 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Inverter Voltage1"}, "state": "'"$inverter_voltage1"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_inverter_voltage1 $EntityLogOutput

curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "Inverter Current2"}, "state": "'"$inverter_current2"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_inverter_current2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Inverter Power2"}, "state": "'"$inverter_power2"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_inverter_power2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Inverter Voltage2"}, "state": "'"$inverter_voltage2"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_inverter_voltage2 $EntityLogOutput


#Load
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "Load Current"}, "state": "'"$load_current"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_load_current $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "frequency", "state_class":"measurement", "unit_of_measurement": "Hz", "friendly_name": "Load Freq"}, "state": "'"$load_frequency"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_load_frequency $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Load Power"}, "state": "'"$load_power"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_load_power $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Load Total Power"}, "state": "'"$load_totalpower"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_load_totalpower $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "Load Voltage"}, "state": "'"$load_voltage"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_load_voltage $EntityLogOutput

curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Load UPS Power L1"}, "state": "'"$load_upsPowerL1"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_load_upspowerl1 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Load UPS Power L2"}, "state": "'"$load_upsPowerL2"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_load_upspowerl2 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Load UPS Power L3"}, "state": "'"$load_upsPowerL3"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_load_upspowerl3 $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "Load UPS Power Total"}, "state": "'"$load_upsPowerTotal"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_loadupspowertotal $EntityLogOutput



#SolarPanels
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "PV1 Current"}, "state": "'"$pv1_current"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv1_current $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "PV1 Power"}, "state": "'"$pv1_power"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv1_power $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "PV1 Voltage"}, "state": "'"$pv1_voltage"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv1_voltage $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "PV2 Current"}, "state": "'"$pv2_current"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv2_current $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "PV2 Power"}, "state": "'"$pv2_power"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv2_power $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "PV2 Voltage"}, "state": "'"$pv2_voltage"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv2_voltage $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "PV1 Current"}, "state": "'"$pv3_current"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv3_current $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "PV1 Power"}, "state": "'"$pv3_power"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv3_power $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "PV1 Voltage"}, "state": "'"$pv3_voltage"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv3_voltage $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "current", "state_class":"measurement", "unit_of_measurement": "A", "friendly_name": "PV2 Current"}, "state": "'"$pv4_current"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv4_current $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power", "state_class":"measurement", "unit_of_measurement": "W", "friendly_name": "PV2 Power"}, "state": "'"$pv4_power"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv4_power $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "voltage", "state_class":"measurement", "unit_of_measurement": "V", "friendly_name": "PV2 Voltage"}, "state": "'"$pv4_voltage"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_pv4_voltage $EntityLogOutput


#Settings Sensors
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog1 Time"}, "state": "'"$prog1_time"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog1_time $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog2 Time"}, "state": "'"$prog2_time"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog2_time $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog3 Time"}, "state": "'"$prog3_time"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog3_time $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog4 Time"}, "state": "'"$prog4_time"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog4_time $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog5 Time"}, "state": "'"$prog5_time"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog5_time $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog6 Time"}, "state": "'"$prog6_time"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog6_time $EntityLogOutput

curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog1 Charge"}, "state": "'"$prog1_charge"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog1_charge $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog2 Charge"}, "state": "'"$prog2_charge"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog2_charge $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog3 Charge"}, "state": "'"$prog3_charge"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog3_charge $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog4 Charge"}, "state": "'"$prog4_charge"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog4_charge $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog5 Charge"}, "state": "'"$prog5_charge"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog5_charge $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog6 Charge"}, "state": "'"$prog6_charge"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog6_charge $EntityLogOutput

curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog1 Capacity"}, "state": "'"$prog1_capacity"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog1_capacity $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog2 Capacity"}, "state": "'"$prog2_capacity"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog2_capacity $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog3 Capacity"}, "state": "'"$prog3_capacity"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog3_capacity $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog4 Capacity"}, "state": "'"$prog4_capacity"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog4_capacity $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog5 Capacity"}, "state": "'"$prog5_capacity"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog5_capacity $EntityLogOutput

curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Prog6 Capacity"}, "state": "'"$prog6_capacity"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_prog6_capacity $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "power_tor", "state_class":"measurement", "unit_of_measurement": "%", "friendly_name": "Battery Shutdown_cap"}, "state": "'"$battery_shutdown_cap"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_battery_shutdown_cap $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "time", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Use Timer"}, "state": "'"$use_timer"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_use_timer $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "", "state_class":"measurement", "unit_of_measurement": "", "friendly_name": "Priority Load"}, "state": "'"$priority_load"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_priority_load $EntityLogOutput

#Other
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"unit_of_measurement": "", "friendly_name": "Inverter Overall State"}, "state": "'"$overall_state"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_overall_state $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "temperature", "state_class":"measurement", "unit_of_measurement": "°C", "friendly_name": "Inverter DC Temp"}, "state": "'"$dc_temp"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_dc_temperature $EntityLogOutput
curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"device_class": "temperature", "state_class":"measurement", "unit_of_measurement": "°C", "friendly_name": "Inverter AC Temp"}, "state": "'"$ac_temp"'"}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/sensor.solarsynk_"$inverter_serial"_ac_temperature $EntityLogOutput

echo "------------------------------------------------------------------------------"
echo "Reading settings entity -> solarsynk_"$inverter_serial"_inverter_settings"
echo "------------------------------------------------------------------------------"
CheckEntity=$(curl -s -k -X GET -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json"  $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/input_text.solarsynk_"$inverter_serial"_inverter_settings | jq -r '.message')

if [ $CheckEntity == "Entity not found." ]
then
	echo "Entity does not exist! Manually create it for this inverter using the HA GUI in menu [Settings] -> [Devices & Services] -> [Helpers] tab -> [+ CREATE HELPER]. Choose [Text] and name it [solarsynk_"$inverter_serial"_inverter_settings]"
	echo "Settings pushback system aborted. Note this is not an error, setting up inverter settings push back is optional. It just means you omitted this part of the setup."
	echo "------------------------------------------------------------------------------"	
else
	InverterSettings=$(curl -s -k -X GET -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json"  $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/input_text.solarsynk_"$inverter_serial"_inverter_settings | jq -r '.state')
	if [[ -z $InverterSettings ]]; then
	  echo "Helper entity input_text.solarsynk_"$inverter_serial"_inverter_settings has no value. Therefore no inverter setting will be sent for change."
	else
		echo "Updating Helper: input_text.solarsynk_"$inverter_serial"_inverter_settings with:" $InverterSettings
		curl -s -k -X POST -H "Content-Type: application/json" -H "authorization: Bearer $ServerAPIBearerToken" https://api.sunsynk.net/api/v1/common/setting/$inverter_serial/set -d $InverterSettings | jq -r '.'
	fi 
	#Reset settings entitities to prevent the same settings from being posted over and over
	echo "Clearing previously set temporary settings."
	curl -s -k -X POST -H "Authorization: Bearer $HA_LongLiveToken" -H "Content-Type: application/json" -d '{"attributes": {"unit_of_measurement": "", "friendly_name": "solarsynk_inverter_settings"}, "state": ""}' $HTTP_Connect_Type://$Home_Assistant_IP:$Home_Assistant_PORT/api/states/input_text.solarsynk_"$inverter_serial"_inverter_settings > /dev/null
fi



# EOF Serial Number Loop
echo "Fetch complete for inverter: $inverter_serial"
done


	
fi
#EOF Check if Token is valid

echo "All Done! Waiting " $Refresh_rate " sesonds to rinse and repeat."
sleep $Refresh_rate
done
