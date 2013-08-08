#!/bin/sh
# Wiwiz HotSpot Builder Utility
# Copyright wiwiz.com. All rights reserved.

VERSION="1.2.3"

GW_ID=087B3A9C
USERNAME=wiwiz
ETNIF=eth1
GWIF=br-lan
AS_HOSTNAME="cp.wiwiz.com:80,cp2.wiwiz.com:80,42.121.98.148:80,74.117.62.156:80,74.117.62.157:80"
#AS_HTTPPORT=80

AS_PATH=/as/s/
WIFIDOG_CONFPATH=/etc

UPDATE_URL_BASE=http://dl.wiwiz.com/hsbuilder-util

#WIFIDOG_START="wifidog"
WIFIDOG_START="wifidog-init start"

DEST=""

ENVINFO="OpenWRT"
#*ENVINFO2="$(nvram get DD_BOARD)|$(nvram get boardtype)|$(nvram get dist_type)"

ENVINFO2="$ENVINFO  $(uname -m)"
ENVINFO2=${ENVINFO2//' '/_}

SILENCEMODE="false"

getAsHostname1() {
	_AsHostname="$1"
	
	for i in 1 2 3 4 5 6 7 8 9; do
		STR=$(echo "$_AsHostname" | cut -d ',' -f $i)
		if [ "$STR" != "" ]; then
			_HOST=$(echo "$STR" | cut -d ':' -f 1)
			_PORT=$(echo "$STR" | cut -d ':' -f 2)
			ping -c 1 "$_HOST" 1>/dev/null 2>/dev/null
			if [ $? = "0" ]; then
				echo "$STR"
				return
			fi
		else
			return
		fi	
	done
}

getAsHostname2() {
	_AsHostname="$1"
	
	for i in 1 2 3 4 5 6 7 8 9; do
		STR=$(echo "$_AsHostname" | cut -d ',' -f $i)
		if [ "$STR" != "" ]; then
			_HOST=$(echo "$STR" | cut -d ':' -f 1)
			_PORT=$(echo "$STR" | cut -d ':' -f 2)
			
			wget -O /tmp/hsbuilder_ping "http://$STR/as/s/ping/" 1>/dev/null 2>/dev/null &
			sleep 4
			PONG=$(cat /tmp/hsbuilder_ping)
			rm -f /tmp/hsbuilder_ping
			
			if [ "$PONG" = "Pong" ]; then
				echo "$STR"
				return
			fi
		else
			return
		fi	
	done
}

getAsHostname() {
	S=$(getAsHostname1 "$1")
	
	if [ "$S" = "" ]; then
		S=$(getAsHostname2 "$1")
	fi
	
	echo $S
	return
}

if [ "$1" = "-dest" ]; then
	if [ ! -d "$2" ]; then
		echo "Error: $2 does not exist!"
		exit 1
	else
		DEST="$2"
	fi
	shift 2
fi

MY_CONF="$DEST/usr/local/hsbuilder/hsbuilder.conf"

#*CRONTAB_FILE="/tmp/crontab"
#*STARTUP_VAR="rc_startup"
#*FIREWALL_VAR="rc_firewall"

COMMENT="#used by hsbuilder"
HSBUILDER_CMD="$DEST/usr/local/hsbuilder/hsbuilder.sh -conf $MY_CONF -mypath $DEST/usr/local/hsbuilder/hsbuilder.sh -nomsgfile -envinfo $ENVINFO 1>/dev/null 2>/dev/null"
HSBUILDER_HELPER="$DEST/usr/local/hsbuilder/hsbuilder_helper.sh -os openwrt -dest $DEST"
CRONTAB_TXT1="*/1 * * * * $HSBUILDER_HELPER $COMMENT"
CRONTAB_TXT2="*/10 * * * * $HSBUILDER_CMD && cp -f $WIFIDOG_CONFPATH/wifidog.conf $DEST/usr/local/hsbuilder/wifidog.conf $COMMENT"

if [ "$1" = "-help" -o "$1" = "" ]; then
	echo "Version: $VERSION"
	echo "Usage:"
	echo "To setup:      hsbuilder_setup4openwrt.sh [-dest DIR] setup"
	echo "To setup(silence mode):  hsbuilder_setup4openwrt.sh -dest DIR qsetup -hotspotid YOUR_HOTSPOT_ID -username YOUR_USERNAME [-srv SERVER_NAME:PORT]"
	echo "To uninstall:  hsbuilder_setup4openwrt.sh [-dest DIR] uninstall"
	echo "To disable:    hsbuilder_setup4openwrt.sh disable"
	echo "To show usage: hsbuilder_setup4openwrt.sh -help"
	echo "For more information, please visit http://www.wiwiz.com"
	exit 0
fi

if [ "$1" = "uninstall" ]; then
#	delete from crontab
	crontab -l | grep -v "$COMMENT" | crontab -
	
#	delete from startup script
#	stop wifidog
	wdctl stop
	
#	delete files
	rm -rf $DEST/usr/local/hsbuilder
	rm -rf /tmp/hsbuilder*
	
	echo "Uninstalled!"
	echo "Please reboot your OpenWRT device to take effect."
	exit 0
fi

if [ "$1" = "disable" ]; then
#	delete from crontab
	crontab -l | grep -v "$COMMENT" | crontab -

#	stop wifidog
	wdctl stop

	rm -f $DEST/usr/local/hsbuilder/wifidog.conf
	rm -rf /tmp/hsbuilder*
	
	echo "Service disabled!"
	echo "Please reboot your OpenWRT device to take effect."
	exit 0
fi

if [ "$1" = "setup" -o "$1" = "qsetup" ]; then

if [ "$1" = "qsetup" ]; then
	SILENCEMODE="true"
fi

shift 1

which wifidog 1>/dev/null
if [ "$?" != "0" ]; then
	echo "Error: Wifidog is not installed. Please install Wifidog."
	echo "  You can do it by running the following command: "
	echo "  opkg install wifidog"
	exit 3
fi

rm -f $DEST/usr/local/hsbuilder/wifidog.conf
rm -rf /tmp/hsbuilder*

if [ -e "$MY_CONF" ]; then
	GW_ID=`cat $MY_CONF | grep -v "^#" | grep GW_ID | cut -d = -f 2`
	USERNAME=`cat $MY_CONF | grep -v "^#" | grep USERNAME | cut -d = -f 2`
	ETNIF=`cat $MY_CONF | grep -v "^#" | grep ETNIF | cut -d = -f 2`
	GWIF=`cat $MY_CONF | grep -v "^#" | grep GWIF | cut -d = -f 2`
	AS_HOSTNAME=`cat $MY_CONF | grep -v "^#" | grep AS_HOSTNAME | cut -d = -f 2`
#	AS_HTTPPORT=`cat $MY_CONF | grep -v "^#" | grep AS_HTTPPORT | cut -d = -f 2`
fi

#get names of netword device
#ETNIF=$(get_wanface)
#GWIF=$(nvram get lan_ifname)

if [ "$SILENCEMODE" = "false" ]; then
	_S=$(cat /proc/net/dev | tail -n +3 | cut -d ':' -f 1)
	_SS=$(echo $_S)
	NETDEV=${_SS//' '/'/'}

	echo "Please input Hotspot ID: (default: $GW_ID)"
	read v
	[ "$v" != "" ] && GW_ID=$v

	echo "Please input User Name: (default: $USERNAME)"
	read v
	[ "$v" != "" ] && USERNAME=$v
	
	echo "please input External NIC (typically the one going out to the Inernet): (default: $ETNIF , or choose one from $NETDEV)"
	read v
	[ "$v" != "" ] && ETNIF=$v

	echo "please select Internal NIC (typically your wifi interface): (default: $GWIF , or choose one from $NETDEV)"
	read v
	[ "$v" != "" ] && GWIF=$v	

	echo "please input Server Address and Port: (default: $AS_HOSTNAME)"
	read v
	[ "$v" != "" ] && AS_HOSTNAME=$v

else

	if [ "$1" = "-hotspotid" ]; then
		GW_ID="$2"
		shift 2
	fi

	if [ "$1" = "-username" ]; then
		USERNAME="$2"
		shift 2
	fi

	if [ "$1" = "-eif" ]; then
		ETNIF="$2"
		shift 2
	fi

	if [ "$1" = "-gwif" ]; then
		GWIF="$2"
		shift 2
	fi
	
	if [ "$1" = "-srv" ]; then
		AS_HOSTNAME="$2"
		shift 2
	fi	

fi

TMPFILE="/tmp/hsbuilder.tmp"

echo "Setting up. It may take a while, please wait ... "

#--- Write hsbuilder.conf starts
cp -f $MY_CONF "$MY_CONF.bak"
rm -f $MY_CONF
echo "GW_ID=$GW_ID" >>                           $MY_CONF
echo "USERNAME=$USERNAME" >>                     $MY_CONF
echo "ETNIF=$ETNIF" >>                           $MY_CONF
echo "GWIF=$GWIF" >>                             $MY_CONF
echo "AS_HOSTNAME=$AS_HOSTNAME" >>               $MY_CONF
#echo "AS_HTTPPORT=$AS_HTTPPORT" >>               $MY_CONF
echo "AS_PATH=$AS_PATH" >>                       $MY_CONF
echo "WIFIDOG_CONFPATH=$WIFIDOG_CONFPATH" >>     $MY_CONF
echo "UPDATE_URL_BASE=$UPDATE_URL_BASE" >>       $MY_CONF
#--- Write hsbuilder.conf ends


# start  hsbuilder.sh and Wifidog !!!

AS_HOSTNAME_X=$(getAsHostname "$AS_HOSTNAME")
#_HOST=$(echo "$AS_HOSTNAME_X" | cut -d ':' -f 1)
#_PORT=$(echo "$AS_HOSTNAME_X" | cut -d ':' -f 2)
	
$DEST/usr/local/hsbuilder/hsbuilder.sh -conf $MY_CONF -mypath $DEST/usr/local/hsbuilder/hsbuilder.sh -nomsgfile -noresolve -envinfo "$ENVINFO" 2>$TMPFILE
CODE="$?"
if [ $CODE = "0" ]; then
	cp -f $WIFIDOG_CONFPATH/wifidog.conf $DEST/usr/local/hsbuilder/wifidog.conf
	
	wdctl stop 2>/dev/null
	sleep 2
	$WIFIDOG_START 2>$TMPFILE
	if [ "$?" != "0" ]; then
		echo "HSBuilder Utility Running Failed! Wifidog Error: $(cat $TMPFILE)" 
		rm -f $TMPFILE
		exit 4	
	fi
else
	echo "HSBuilder Utility Running Failed! Error Code: $CODE"
	echo "Error Message: $(cat $TMPFILE)"
	echo "Please report this problem to support@wiwiz.com"
	rm -f $TMPFILE
	
	wdctl stop
	exit 2
fi


#--- Set Crontab Starts
rm -f $TMPFILE
crontab -l 2>/dev/null | grep -v "$COMMENT">$TMPFILE 
echo "$CRONTAB_TXT1" >>$TMPFILE
echo "$CRONTAB_TXT2" >>$TMPFILE
crontab $TMPFILE
#--- Set Crontab Ends


echo "HSBuilder Setup Completed!"
rm -f $TMPFILE

URL="http://$AS_HOSTNAME_X/as/s/readconf/?m=info&gw_id=$GW_ID&e2=$ENVINFO2"
wget -O - "$URL" >/dev/null 2>/dev/null

fi
