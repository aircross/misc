#!/bin/sh
# Wiwiz HotSpot Builder Utility
# Copyright wiwiz.com. All rights reserved.

MY_VERSION="1.2.3"
VER_BASE="hsbuilder"

ENVINFO=''
CONFPATH='/usr/local/hsbuilder/hsbuilder.conf'
ADDRLIST='/tmp/hsbuilder_addrlist.txt'
TRUSTMAC='/tmp/hsbuilder_trustmac'
DOMAINNAME='/tmp/hsbuilder_domainname.txt'
TIMEOUT="10"
IPLIST='/tmp/hsbuilder_iplist.txt'
BLOCKPORT='/tmp/hsbuilder_blockport.txt'
WD_CONF_TMP='/tmp/hsbuilder_wdconf.tmp'
LOGFILE='/tmp/hsbuilder.log'
EOF_FLAG='###END_OF_FILE###'
WDCTL="wdctl"
NSLOOKUPOK="1"
SORT="1"
which sort 1>/dev/null 2>/dev/null
if [ $? != 0 ]; then
	SORT="0"	#no sort
else
	SORT="1"
fi

#MY_FULLPATH=$(dirname -- $(readlink -f -- "$0"))/hsbuilder.sh
MY_FULLPATH="/usr/local/hsbuilder/hsbuilder.sh"
MSG_FILE="/usr/local/hsbuilder/msgfile.htm"
NORESOLVE="false"

HSB_OPT=$(cat /tmp/hsbuilder_option 2>/dev/null)
if [ "$HSB_OPT" = "noresolve" ]; then
	NORESOLVE="true"
fi

#if [ "$SORT" = "0" ]; then
#	NORESOLVE="true"
#fi

getAsHostname1() {
	_AsHostname="$1"
	
	for i in 1 2 3 4 5 6 7 8 9; do
		STR=$(echo "$_AsHostname" | cut -d ',' -f $i)
		if [ "$STR" != "" ]; then
			_HOST=$(echo "$STR" | cut -d ':' -f 1)
			_PORT=$(echo "$STR" | cut -d ':' -f 2)
			ping -c 2 "$_HOST" 1>/dev/null 2>/dev/null
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

doConfig() {
	SURL="$1"
	NR="$2"
	
	#get config data
	wget -O - "$SURL" > $ADDRLIST 2>/dev/null
	
	if [ "`tail -n 1 $ADDRLIST`" = $EOF_FLAG ]; then
		cat $ADDRLIST | grep -v "$EOF_FLAG" | while read LINE; do
			#echo LINE=$LINE
			ACTION=$(echo $LINE | cut -d " " -f 1)
			ACDATA=$(echo $LINE | cut -d " " -f 2)

			if [ "$ACTION" = "TM" ]; then
				echo "$ACDATA" >$TRUSTMAC
			elif [ "$ACTION" = "TO" ]; then
				TIMEOUT="$ACDATA"
			    echo "$(cat $CONFPATH | grep -v TIMEOUT)" > "$CONFPATH"
			    echo "TIMEOUT=$TIMEOUT" >> "$CONFPATH"				
			elif [ "$ACTION" = "UW" ]; then
				makeFwRule "$ACDATA" "FirewallRule allow to" "$NR" "U" "$IPLIST"
			elif [ "$ACTION" = "UB" ]; then
				makeFwRule "$ACDATA" "FirewallRule block to" "$NR" "U" "$IPLIST"
			elif [ "$ACTION" = "SW" ]; then
				makeFwRule "$ACDATA" "FirewallRule allow to" "$NR" "S" "$IPLIST"
			elif [ "$ACTION" = "SB" ]; then
				makeFwRule "$ACDATA" "FirewallRule block to" "$NR" "S" "$IPLIST"
			elif [ "$ACTION" = "BP" ]; then
				PORTTYPE=$(echo $ACDATA | cut -d ":" -f 1)
				PORTNUM=$(echo $ACDATA | cut -d ":" -f 2)				
				echo "FirewallRule block $PORTTYPE port $PORTNUM" >>"$BLOCKPORT"
			fi
		done
	else
#		echo "Data Download Failed."
		return 1	  
	fi
	
	return 0
}


makeFwRule() {
#	SURL="$1"
	DATA="$1"
	PRX="$2"
	NR="$3"
	COMMENT='#'"$4"
	OUTPUT="$5"
	
	#get address
    ADDRTYPE=$(echo $DATA | cut -d ":" -f 1)
    ADDR=$(echo $DATA | cut -d ":" -f 2)
    
    # if it is a domain name
    if [ "$ADDRTYPE" = "DN" ]; then
    	DOMAIN=$ADDR
    	if [ "$COMMENT" = '#U' ]; then
    		echo "U:DN:$DOMAIN" >>$DOMAINNAME
    	fi
    	
    	#if [ "$NR" != "true" ]; then
    	if [ "$NR" = "true" -a "$COMMENT" != '#U' ]; then
    		NOTHINGTODO=1
    	else
    		#which nslookup 1>/dev/null 2>/dev/null
	        #if [ $? != 0 ]; then
	        if [ "$NSLOOKUPOK" != "1" ]; then
	            ADDR=`ping -c 1 $ADDR 2>>$LOGFILE | grep PING | awk '{print $3}' | tr -d "(" | tr -d ")"`
	            if [ "$ADDR" != "" ]; then
	            	if [ "$COMMENT" = '#U' ]; then
	            		GRP=$(grep "$PRX $ADDR" $OUTPUT)
	            		if [ "$GRP"='' ]; then
	            			echo "$PRX $ADDR    $COMMENT:DN:$DOMAIN" >>$OUTPUT
	            		fi
	            	else
	            		echo "$PRX $ADDR    $COMMENT" >>$OUTPUT
	            	fi
				fi
	        else
	            NSLKP_RST="/tmp/hsbuilder_nslookup.txt"
	            nslookup $ADDR | tail -n +5 | grep Address | cut -d ":" -f 2 | cut -d " " -f 2 > $NSLKP_RST
	            
	            cat $NSLKP_RST | while read LINE2; do
	            	if [ "$COMMENT" = '#U' ]; then
	            		GRP=$(grep "$PRX $LINE2" $OUTPUT)
	            		if [ "$GRP"='' ]; then
	                		echo "$PRX $LINE2    $COMMENT:DN:$DOMAIN" >>$OUTPUT
	                	fi
	                else
	                	echo "$PRX $LINE2    $COMMENT" >>$OUTPUT
	                fi
	            done
	            
	            rm -f $NSLKP_RST
	        fi
	    fi
    # if it is an IP
    else
        if [ "$ADDR" != "" ]; then
        	if [ "$COMMENT" = '#U' ]; then
				GRP=$(grep "$PRX $ADDR" $OUTPUT)
	            if [ "$GRP"='' ]; then
        			echo "$PRX $ADDR    $COMMENT" >>$OUTPUT
        		fi
        	else
        		echo "$PRX $ADDR    $COMMENT" >>$OUTPUT
        	fi
        fi
    fi
}


if [ "$1" = "-help" ]; then
	echo "Usage:"
	echo "hsbuilder [-conf XXX] [-mypath XXX]"
	echo "To show usage: hsbuilder -help"
	exit 0
fi

if [ "$1" = "-conf" ]; then
	if [ "$2" = "" ]; then
	    CONFPATH=$CONFPATH
	else
	    CONFPATH="$2"
	fi
	shift 2
fi

if [ "$1" = "-mypath" ]; then
	if [ "$2" = "" ]; then
	    MY_FULLPATH=$MY_FULLPATH
	else
	    MY_FULLPATH="$2"
	fi
	shift 2
fi

if [ "$1" = "-msgfile" ]; then
	if [ "$2" = "" ]; then
	    MSG_FILE=$MSG_FILE
	else
	    MSG_FILE="$2"
	fi
	shift 2
fi

if [ "$1" = "-nomsgfile" ]; then
	MSG_FILE=""
	shift 1
fi

if [ "$1" = "-noresolve" ]; then
	NORESOLVE="true"
	shift 1
fi

if [ "$1" = "-envinfo" ]; then
	if [ "$2" = "" ]; then
	    ENVINFO="$ENVINFO"
	else
	    ENVINFO="$2"
	fi
	shift 2
fi


# Starts
if [ -e "$ADDRLIST" ]; then
	echo "Another process is running." >&2
	echo "Another process is running." >>$LOGFILE
	exit 5
fi

if [ ! -e "$CONFPATH" ]; then
	echo "Configuration File Not Exist." >&2
	echo "Configuration File Not Exist." >>$LOGFILE
	exit 1
fi

#read conf file
echo "Reading Configuration File ..."

GW_ID=`cat $CONFPATH | grep -v "^#" | grep GW_ID | cut -d = -f 2`
USERNAME=`cat $CONFPATH | grep -v "^#" | grep USERNAME | cut -d = -f 2`
ETNIF=`cat $CONFPATH | grep -v "^#" | grep ETNIF | cut -d = -f 2`
GWIF=`cat $CONFPATH | grep -v "^#" | grep GWIF | cut -d = -f 2`
AS_HOSTNAME=`cat $CONFPATH | grep -v "^#" | grep AS_HOSTNAME | cut -d = -f 2`
#AS_HTTPPORT=`cat $CONFPATH | grep -v "^#" | grep AS_HTTPPORT | cut -d = -f 2`
AS_PATH=`cat $CONFPATH | grep -v "^#" | grep AS_PATH | cut -d = -f 2`
WIFIDOG_CONFPATH=`cat $CONFPATH | grep -v "^#" | grep WIFIDOG_CONFPATH | cut -d = -f 2`
UPDATE_URL_BASE=`cat $CONFPATH | grep -v "^#" | grep UPDATE_URL_BASE | cut -d = -f 2`

#echo "GW_ID=$GW_ID"
#echo "USERNAME=$USERNAME"
#echo "ETNIF=$ETNIF"
#echo "GWIF=$GWIF"
#echo "AS_HOSTNAME=$AS_HOSTNAME"
#echo "AS_HTTPPORT=$AS_HTTPPORT"
#echo "AS_PATH=$AS_PATH"
#echo "WIFIDOG_CONFPATH=$WIFIDOG_CONFPATH"
#echo "UPDATE_URL_BASE=$UPDATE_URL_BASE"

echo "Downloading data and setting up, please wait..."

_WIFIDOG_CONFFILE=$WIFIDOG_CONFPATH/wifidog.conf
mkdir -p $WIFIDOG_CONFPATH 2>/dev/null

rm -f $DOMAINNAME
rm -f $IPLIST
rm -f $BLOCKPORT
touch $IPLIST
touch $BLOCKPORT
touch $DOMAINNAME
touch $IPLIST.lasttime
echo "HSBuilder: $(date)" >> $LOGFILE

AS_HOSTNAME_X=$(getAsHostname "$AS_HOSTNAME")
if [ "$AS_HOSTNAME_X" = "" ]; then
	echo "Server is not reachable." >&2
	echo "Server is not reachable." >>$LOGFILE
	exit 4
fi

#-- get lastest server address --
wget -O - "http://$AS_HOSTNAME_X/as/s/readconf/?m=srv" > $ADDRLIST 2>/dev/null
if [ "`tail -n 1 $ADDRLIST`" = "$EOF_FLAG" ]; then
    SRV=$(cat $ADDRLIST | grep -v "$EOF_FLAG")
    
    if [ "$SRV" != "" ]; then
	    echo "$(cat $CONFPATH | grep -v AS_HOSTNAME)" > "$CONFPATH"
	    echo "AS_HOSTNAME=$SRV" >> "$CONFPATH"
	    
	    if [ "$SRV" != "$AS_HOSTNAME" ]; then
			AS_HOSTNAME_X=$(getAsHostname "$SRV")
			if [ "$AS_HOSTNAME_X" = "" ]; then
				echo "Server is not reachable." >&2
				echo "Server is not reachable." >>$LOGFILE
				exit 4
			fi
	    fi
    fi
fi

which nslookup 1>/dev/null 2>/dev/null
if [ $? != 0 ]; then
	NSLOOKUPOK="0"
else
	NSLOOKUPOK="1"
fi

doConfig "http://$AS_HOSTNAME_X/as/s/readconf2/?m=all&gw_id=$GW_ID&username=$USERNAME&envinfo=$ENVINFO&ver=$MY_VERSION" "$NORESOLVE"
if [ $? != "0" ]; then
	rm -f $ADDRLIST
	rm -f $IPLIST
	rm -f $BLOCKPORT
	rm -f $DOMAINNAME
	echo "Configuration Data Download and Setup Failed." >&2
	echo "Configuration Data Download and Setup Failed." >>$LOGFILE
	exit 2
fi

if [ "$SORT" = "1" ]; then
	grep '#S' $IPLIST.lasttime >> $IPLIST
	if [ "$(uniq $DOMAINNAME)" != "" ]; then
		grep -f $DOMAINNAME $IPLIST.lasttime >> $IPLIST
	fi
	cat $IPLIST | sort | uniq > $IPLIST.2
else
	grep '#S' $IPLIST.lasttime > $IPLIST.3
	if [ "$(uniq $DOMAINNAME)" != "" ]; then
		grep -f $DOMAINNAME $IPLIST.lasttime >> $IPLIST.3
	fi

	cat $IPLIST.3 >$IPLIST.2
		
	if [ "$(uniq $IPLIST.3)" != "" ]; then
		uniq $IPLIST | grep -v -f $IPLIST.3 >>$IPLIST.2
	else
		uniq $IPLIST >>$IPLIST.2
	fi
fi

#
grep '#' $IPLIST.2 > $IPLIST.3
grep -v '(null)' $IPLIST.3 > $IPLIST
rm -f $IPLIST.2 $IPLIST.3

## compare IP lists
#_iplist=$(cat $IPLIST)
#_iplist_old=$(cat $IPLIST.lasttime)
#if [ "$_iplist" != "$_iplist_old" ]; then

_HOST=$(echo "$AS_HOSTNAME_X" | cut -d ':' -f 1)
_PORT=$(echo "$AS_HOSTNAME_X" | cut -d ':' -f 2)

#make /tmp/hsbuilder_wdconf.tmp
echo 'GatewayID '$GW_ID >                             $WD_CONF_TMP
echo 'ExternalInterface '$ETNIF >>                     $WD_CONF_TMP
echo 'GatewayInterface '$GWIF >>                     $WD_CONF_TMP

if [ "$MSG_FILE" != "" ]; then
	echo "HtmlMessageFile $MSG_FILE" >>                 $WD_CONF_TMP
fi

echo 'AuthServer {' >>                                 $WD_CONF_TMP
echo 'Hostname '$_HOST >>                 $WD_CONF_TMP
echo 'HTTPPort '$_PORT >>                 $WD_CONF_TMP
echo 'Path '$AS_PATH >>                         $WD_CONF_TMP
echo '}' >>                                         $WD_CONF_TMP
echo 'HTTPDMaxConn 100' >>                             $WD_CONF_TMP

_TrustMac=$(cat "$TRUSTMAC" 2>/dev/null)
if [ "$_TrustMac" != "" ]; then
	echo "TrustedMACList $_TrustMac" >>                 $WD_CONF_TMP
fi

TIMEOUT=`cat $CONFPATH | grep -v "^#" | grep TIMEOUT | cut -d = -f 2`
echo "ClientTimeout $TIMEOUT" >>                       $WD_CONF_TMP

echo 'FirewallRuleSet global {' >>                     $WD_CONF_TMP
cat $IPLIST >>                                      $WD_CONF_TMP       #!!!
echo '}' >>                                         $WD_CONF_TMP
echo 'FirewallRuleSet validating-users {' >>         $WD_CONF_TMP
echo 'FirewallRule allow to 0.0.0.0/0' >>         $WD_CONF_TMP
echo '}' >>                                         $WD_CONF_TMP
echo 'FirewallRuleSet known-users {' >>             $WD_CONF_TMP
echo 'FirewallRule allow to 0.0.0.0/0' >>         $WD_CONF_TMP
echo '}' >>                                         $WD_CONF_TMP
echo 'FirewallRuleSet unknown-users {' >>             $WD_CONF_TMP
echo 'FirewallRule allow udp port 53' >>         $WD_CONF_TMP
echo 'FirewallRule allow tcp port 53' >>         $WD_CONF_TMP
echo 'FirewallRule allow udp port 67' >>         $WD_CONF_TMP
echo 'FirewallRule allow tcp port 67' >>         $WD_CONF_TMP
cat $BLOCKPORT >>                               $WD_CONF_TMP       #!!!
echo '}' >>                                      $WD_CONF_TMP

# compare wifidog.conf
touch $_WIFIDOG_CONFFILE
_wifidog_conf=$(cat $_WIFIDOG_CONFFILE)
_wifidog_conf_new=$(cat $WD_CONF_TMP)

if [ "$_wifidog_conf" != "$_wifidog_conf_new" ]; then
	# generate new wifidog.conf
	cp -f $WD_CONF_TMP $_WIFIDOG_CONFFILE
	
	# reload wifidog.conf
	$WDCTL restart

	# back up iplist
	cp -f $IPLIST $IPLIST.lasttime
	
	echo "Wifidog conf file changed." >>$LOGFILE
fi

#--- Update starts
#echo "Checking new version ..."
#CUR_FULL_VERSION=$(wget -O - "$UPDATE_URL_BASE/latest/version.txt" 2>/dev/null)
#CUR_VER_BASE=$(echo $CUR_FULL_VERSION | cut -d " " -f 1)
#CUR_VERSION=$(echo $CUR_FULL_VERSION | cut -d " " -f 2)
##echo "VER_BASE=$VER_BASE CUR_VER_BASE=$CUR_VER_BASE    CUR_VERSION=$CUR_VERSION"
#
#if [ $? = 0 -a "$CUR_VERSION" != "" -a "$CUR_VER_BASE" = "$VER_BASE" ]; then
#    if [ "$MY_VERSION" \< "$CUR_VERSION" ]; then
#      wget -O - "$UPDATE_URL_BASE/latest/update.sh" > $MY_FULLPATH.tmp 2>/dev/null
#      
#      if [ $? = 0 -a -s $MY_FULLPATH.tmp ]; then  #if everythin is ok
#        cp -f $MY_FULLPATH $MY_FULLPATH-$MY_VERSION.bak
#        cp -f $MY_FULLPATH.tmp $MY_FULLPATH
#        rm -f $MY_FULLPATH.tmp
#        echo "File updated."
#        echo "File updated." >>$LOGFILE
#      fi      
#    else
#      echo "No need to update."
#    fi
#else
##	echo "Warning: Update failed!"
#	echo "Warning: Update failed!" >>$LOGFILE
#fi
#--- Update ends

echo "HSBuilder: Done." >>$LOGFILE

sleep 8
rm -f $WD_CONF_TMP
rm -f $ADDRLIST
rm -f $IPLIST
rm -f $BLOCKPORT
rm -f $DOMAINNAME
rm -f $TRUSTMAC 2>/dev/null