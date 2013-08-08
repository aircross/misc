#!/bin/sh
# Wiwiz HotSpot Builder Utility
# Copyright wiwiz.com. All rights reserved.

DEST=""
WIFIDOG_START="wifidog"

LOGFILE='/tmp/hsbuilder.log'

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

if [ "$1" = "-os" ]; then
	if [ "$2" = "openwrt" ]; then
		WIFIDOG_START="wifidog-init start"
	elif [ "$2" = "dd-wrt" ]; then
		WIFIDOG_START="wifidog"
	fi
	
	shift 2
fi

if [ "$1" = "-dest" ]; then
	if [ ! -d "$2" -a "$2" != "" ]; then
		echo "Error: $2 does not exist!"
		exit 1
	else
		DEST="$2"
	fi
	shift 2
fi


CONFPATH=$DEST'/usr/local/hsbuilder/hsbuilder.conf'

AS_HOSTNAME=`cat $CONFPATH | grep -v "^#" | grep AS_HOSTNAME | cut -d = -f 2`
WIFIDOG_CONFPATH=$(cat $CONFPATH | grep -v "^#" | grep WIFIDOG_CONFPATH | cut -d = -f 2)

wdctl status
CODE="$?"

if [ $CODE != "0" ]; then

#	AS_HOSTNAME_X=$(getAsHostname "$AS_HOSTNAME")
#	if [ "$AS_HOSTNAME_X" = "" ]; then
#		echo "Helper: Server is not reachable." >&2
#		echo "Helper: Server is not reachable." >>$LOGFILE
#		exit 4
#	fi
	
	cp -f $DEST/usr/local/hsbuilder/wifidog.conf $WIFIDOG_CONFPATH/wifidog.conf
	$WIFIDOG_START
	exit 0
fi

exit 1