![](https://github.com/martinville/solarsynk_test/blob/main/logo.png)

## How it works
SolarSynk will fetch solar system data via the internet which was initially posted to the cloud via your sunsynk dongle. It does not have any physical interfaces that are connected directly to your inverter. 
Please also note that this add-on only populates sensor values with data. It does not come with any cards to display information.

See full documentation here
https://github.com/martinville/solarsynk/blob/main/DOCS.md

## Getting Started

In order for this add-on to work it needs to publish sensor values to Home Assistant's entities via the HA local API. Therefore a long-lived access token is required.

### Setting up a long-lived access token.
Click your profile picture situated in the bottom left of your HA user-interface. Scroll all the way to the bottom and create a long-lived token. The token name is not important for the solarsynk add-on but obviously the token key is. Make sure you copy it and keep it for use later on.

![](https://github.com/martinville/solarsynk/blob/main/longlivetoken.png)

### Add this respository to your Home Assistant add-on store
From the "Settings" menu item in Home Asstant's UI go to "Add-ons". In the bottom right-hand corner click "ADD-ON STORE". The in the right-hand top corner click the three dots and select "Repositories".
Paste the following repository link and click add then close https://github.com/martinville/solarsynk

![](https://github.com/martinville/solarsynk/blob/main/addrepo.png)

Refresh the browser. Right at the bottom you should now see the "SolarSynk" add-on. Simply click it then click "Install"

![](https://github.com/martinville/solarsynk/blob/main/solarsynkaddon.png)


### Provide your Sunsynk.net credentials
After installing this add-on make sure you enter all the required information on the configuration page. Note if your intentions are to update a Home Assistant installtion with a different IP than the one where this addon is installed, you need to generate the long live token on the Home Assistant instance where entities will be updated. 
DO NOT USE localhost or 127.0.0.1 in the IP field, either use the actual IP or hostname.

![](https://github.com/martinville/solarsynk/blob/main/configuration.png)

In case you are unsure what your Sunsynk inverter's serial number is. Log into the synsynk.net portal and copy the serial number from the "Inverter" menu item.
For multiple inverters seperate the inverter serial numbers with a semi colon ; Example 123456;7890123

![](https://github.com/martinville/solarsynk/blob/main/sunserial.png)

Make sure you also populate the "HA_LongLiveToken" field with the long-lived token that you created earlier on.

### Start the script
After entering all of the required information you can go ahead and start the service script.

![](https://github.com/martinville/solarsynk/blob/main/solarsynkstarted.png)

Once started make sure all is ok by clicking on the "log" tab. Scroll through the log and check that the sensor data was populated correctly.
Few values will be "0" if you for instance only have a single string of solar panels MPPT-2 values will be "0" . If something went wrong ALL of the sensors will have a "0" value. 


