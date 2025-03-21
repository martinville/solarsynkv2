# NOTICE: This repository has been abandoned!
And moved to Version 3 -> https://github.com/martinville/solarsynkv3

## Background
This Home Assistant integration was originally based solely on a bash script but has been migrated to a more developer-friendly Python platform. As a result, upgrading the existing integration is not feasible. Many entity names have changed, likely breaking existing display cards. The new version introduces more entities, automatically detects inverter modules (including multiple MPPTs and grid phases), and features improved error handling.

You are welcome to continue using this repository, but please note that no further updates or improvements will be provided.


![](https://github.com/martinville/solarsynk_test/blob/main/logo.png)


## How it works
SolarSynk will fetch solar system data via the internet which was initially posted to the cloud via your sunsynk dongle. It does not have any physical interfaces that are connected directly to your inverter. 
Please also note that this add-on only populates sensor values with data. It does not come with any cards to display information.

This add-on was developed for Sunsynk Region 2 customers only. Supports multiple inverters.

See for more information: https://github.com/martinville/solarsynkv2/blob/main/DOCS.md

![](https://github.com/martinville/solarsynk/blob/main/solarsynkstarted.png)
