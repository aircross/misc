ABOUT WIWIZ

Wiwiz HotSpot Builder is a wireless/wired Hotspot management system, by which you can create a captive portal. Wiwiz HotSpot Builder is composed wth two parts -  Wiwiz Web Control Panel and a client named Wiwiz HotSpot Builder Utility. In typical scenario, the machine deployed with Wiwiz HotSpot Builder usually acts as the gateway to the Internet in a wireless (or wired) LAN. When a user in this network attempts to use the Internet, he/she firstly needs to open a web browser to access an arbitrary URL, and then a special web page (usually for authentication purposes) will be shown. The authentication has to be done before the user accesses the Internet.

The homepage of Wiwiz is:
    http://www.wiwiz.com

The URL of Wiwiz Web Control Panel is: 
    http://cp.wiwiz.com/as/


------------------
Installation Guide of HotSpot Builder Utility
Installation on an OpenWrt device

1. System requirements
Hardware
 - A wireless router with OpenWrt installed (typically Linksys WRT54G series)

Software
 - Wifidog
   You can try to install Wifidog by running the following command:
     opkg update   # Optional
     opkg install wifidog

Make your wireless router connected to the Internet firstly.


2. Create your Hotspot in the Web Control Panel
Login into the Web Control Panel by accessing http://cp.wiwiz.com/as/s/menu .
Click "My Hotspots", and then click "Create a New Hotspot" in the page displayed. Follow the instructions and fill all the right items, click save.
You can find out the Hotspot ID generated of the Hotspot you just created. Remember it, it will be used in next steps.

3. Configure the HotSpot Builder Utility package
Connect a PC to your wireless router, and SSH into your wireless router from the PC.
Set it up by running the following commands :

 cd; wget http://dl.wiwiz.com/hsbuilder-util-latest-OpenWrt.tar.gz
 cd /; tar -zxf /root/hsbuilder-util-latest-OpenWrt.tar.gz
 /usr/local/hsbuilder/hsbuilder_setup4openwrt.sh setup

Then follow the prompts to complete the setup.
Especially, the Hotspot ID you need to input is the one (NOT the Hotspot Name) that stands for the Hotspot you created in the Web Control Panel.

Now the installation is done if there is not any error message. 

You can test your Hotspot with a Wi-Fi client (such as a PC with WLAN adapter, or a mobile phone supported Wi-Fi) by doing the following steps:
- Search available Wi-Fi Hotspots and connect to the one which yours stands for.
- Open a web browser and try to access an arbitrary URL. If the portal page of your Hotspot is displayed, it means your Hotspot is running normally.
