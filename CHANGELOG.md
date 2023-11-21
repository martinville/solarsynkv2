### 2023/11/12
No Changes - New Implementation

### 2023/11/14
Updated all energy related entity sensors with correct attributes (Affects all enteties with UOM kWh)

### 2023/11/16
Added 2 more entities, sensor.solarsynk_grid_voltage and sensor.solarsynk_grid_current.
Updated all entity devices classes except for Battery Capacity, Battery Type, Grid Connection Status and Inverter Overall State (No device class available)

### 2023/11/17
Added more entities (Will be 0 or null if not available in your setup.
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
Added setting to change the regresh rate (In seconds) to the configuration screen.

### 2023/11/19
Added support for multiple inverters. Take note of a change in entity names. Entities are now prefixed with inverter serial numbers.

### 2023/11/21
Version: "2.1.3" - Bug Fix: Breaks in graphs are caused by null values. All nulls are converted to zero.

