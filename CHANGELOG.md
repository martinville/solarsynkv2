### 2023/11/12
Version: "1.1.1" - No Changes - New Implementation

### 2023/11/14
Version: "1.1.3" - Updated all energy related entity sensors with correct attributes (Affects all enteties with UOM kWh)

### 2023/11/16
Version: "1.1.4" - Added 2 more entities, sensor.solarsynk_grid_voltage and sensor.solarsynk_grid_current.
Updated all entity devices classes except for Battery Capacity, Battery Type, Grid Connection Status and Inverter Overall State (No device class available)

### 2023/11/17
Version: "1.1.5" - Added more entities (Will return 0 or null if not available in your setup.
battery1_voltage, 
battery1_current, 
battery1_power, 
battery1_soc, 
battery1_temperature, 
battery1_status, 
battery2_voltage, 
battery2_current, 
battery2_power, 
battery2_soc, 
battery2_temperature, 
battery2_status

### 2023/11/18
Version: "1.1.6" - Added setting to change the refresh rate (in seconds) to the configuration screen.

### 2023/11/19
Version: "2.1.2" - Added support for multiple inverters. Take note of a change in entity names. Entities are now prefixed with inverter serial numbers.

### 2023/11/21
Version: "2.1.3" - Bug Fix: Breaks in graphs are caused by null values. All nulls are converted to zero.

### 2023/11/21
Version: "2.1.4" - Added option to enter a custom Home Assistant port number.

### 2023/12/18
Version: "2.1.5" - Added option to enter either HTTP or HTTPS for the connection type.

### 2024/01/01
Version: "2.1.6" - Added hostname, port and connect type to log.

### 2024/01/02
Version: "2.1.7" - Simplified log by adding option to show verbose logging. Changed SSL selection with toggle control. Added extra security to hide password and long live token.

### 2024/01/03
Version: "2.1.8" - Added ability to push inverter settings from homeassistant.

### 2024/01/04
Version: "2.1.9" - Added the following entities from settings: prog1_time, prog2_time, prog3_time, prog4_time, prog5_time, prog6_time, prog1_charge, prog2_charge, prog3_charge, prog4_charge, prog5_charge, prog6_charge, prog1_capacity, prog2_capacity, prog3_capacity, prog4_capacity, prog5_capacity, prog6_capacity, battery_shutdown_cap, use_timer, priority_load

### 2024/01/06
Version: "2.1.10" - Added translations en.yaml for all user input fields in the configuration.yaml file.
