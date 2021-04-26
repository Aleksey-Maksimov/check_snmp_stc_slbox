#!/bin/bash
#
# Icinga Plugin Script (Check Command). It get STC Smart Logger Box device current state from SNMP v1/2c data
# Aleksey Maksimov <aleksey.maksimov@it-kb.ru>
#
# Requires 'snmpget' utility
# Tested on Debian GNU/Linux 10.8 (Buster) with snmpget 5.7.3 and Icinga r2.12.3-1
#
# ChangeLog:
# 2021.01.28 - Initial version
# 2021.03.19 - Added error checking for snmpget utility:
#              No Such Object available on this agent at this OID, snmpget: Unknown host ..., Timeout: No Response from ... 
#
# Put here: /usr/lib/nagios/plugins/check_snmp_stc_slbox.sh
# Usage example:
# ./check_snmp_stc_slbox.sh -H slbox-01.holding.com -P 2c -C public -m hdd
#
PLUGIN_NAME="Icinga Plugin Check Command to get STC Smart Logger Box device current state (from SNMP v1/2c data)"
PLUGIN_VERSION="2021.01.28"
PRINTINFO=`printf "\n%s, version %s\n \n" "$PLUGIN_NAME" "$PLUGIN_VERSION"`


# Exit codes
#
codeOK=0
codeWARNING=1
codeCRITICAL=2
codeUNKNOWN=3


# Default thresholds and options
#
vTempWarnDefault="45"
vTempCritDefault="50"
vHDDUsageWarnDefault="95"
vHDDUsageCritDefault="99"
vCHECKRecorder="0"
vCHECKCleaner="0"
vCHECKXCtl="0"
vCHECKFTPServer="0"
vCHECKSMDRAnalyzer="0"


# Plugin options
#
Usage() {
  echo "$PRINTINFO"
  echo "Usage: $0 [OPTIONS]

Option   GNU long option        Meaning
------   ---------------	-------
 -H      --hostname		Host name, IP Address.
				Required option.

 -P      --protocol		SNMP protocol version. Possible values: '1','2c'
				Required option.

 -C      --community		SNMPv1/2c community string for SNMP communication (for example,'public')
				Required option.

 -m	 --mode			Plugin modes. Possible values: 'uptime','sensors','hdd','services'
				Required option.

 -w	 --warning		Warning threshold. The value is used only with modes 'sensors' and 'hdd'
				In 'sensors' mode, the value sets the temperature warning threshold in degrees Celsius. 
				Default value(C): 45
				In 'hdd' mode, the value sets the warning threshold for the use of disk capacity in percent.
                                Default value(%): 95

 -c	 --critical		Сritical threshold. The value is used only with modes 'sensors' and 'hdd'.
				In 'sensors' mode, the value sets the temperature critical threshold in degrees Celsius. 
                                Default value(C): 50
				In 'hdd' mode, the value sets the warning threshold for the use of disk capacity in percent.
				Default value(%): 99

 -R	--check-recorder	Check voice recording service 'Recorder' state.
				If the 'Recorder' service is stopped, phonogram recording does not work.
				The option is used only with 'services' mode. The option is not enabled by default. 

 -Z	--check-cleaner		Check voice records management service 'Cleaner' state.
				If the 'Cleaner' service is stopped, deleting outdated phonograms does not work.
				The option is used only with 'services' mode. The option is not enabled by default.

 -X	--check-xctl		Check control protocol service 'xctl' state. 
				'xctl' is the device control protocol that checks the communication between the base board, 
                                mezzanine and SLBox software.
				The option is used only with 'services' mode. The option is not enabled by default.

 -F	--check-ftpserver	Check 'ftp_server' service state.
				FTP Server service is used for remote access to the phonograms.
				The option is used only with 'services' mode. The option is not enabled by default.

 -S	--check-smdranalyzer	Check 'SmdrAnalyzer' service state. 
				The "SmdrAnalyzer" service is used if the device has an STC-H597 mezzanine (to work with the digital stream E1).
                                In this case, the service processes additional data on phone calls received from the PBX in the SMDR/CDR format.
				The option is used only with 'services' mode. The option is not enabled by default.

 -q      --help			Show this message
 -v      --version		Print version information and exit

"
}


# Parse arguments
#
if [ -z $1 ]; then
    Usage; exit $codeUNKNOWN;
fi
#
OPTS=`getopt -o H:P:C:m:w:c:RZXFSqv -l hostname:,protocol:,community:,mode:,warning:,critical:,check-recorder,check-cleaner,check-xctl,check-ftpserver,check-smdranalyzer,help,version -- "$@"`
eval set -- "$OPTS"
while true; do
   case $1 in
     -H|--hostname) HOSTNAME=$2 ; shift 2 ;;
     -P|--protocol)
        case "$2" in
        "1"|"2c") PROTOCOL=$2 ; shift 2 ;;
        *) printf "Unknown value for option %s. Use '1' or '2c'\n" "$1" ; exit $codeUNKNOWN ;;
        esac ;;
     -C|--community) COMMUNITY=$2 ; shift 2 ;;
     -m|--mode)
        case "$2" in
        "uptime"|"sensors"|"hdd"|"services") MODE=$2 ; shift 2 ;;
        *) printf "Unknown value for option %s. Use 'uptime' or 'sensors' or 'hdd' or 'services'\n" "$1" ; exit $codeUNKNOWN ;;
        esac ;;
     -w|--warning) vWARN=$2 ; shift 2 ;;
     -c|--critical) vCRIT=$2 ; shift 2 ;;
     -R|--check-recorder) vCHECKRecorder="1" ; shift ;;
     -Z|--check-cleaner) vCHECKCleaner="1" ; shift ;;
     -X|--check-xctl) vCHECKXCtl="1" ; shift ;;
     -F|--check-ftpserver) vCHECKFTPServer="1" ; shift ;;
     -S|--check-smdranalyzer) vCHECKSMDRAnalyzer="1" ; shift ;;
     -q|--help)          Usage ; exit $codeOK ;;
     -v|--version)       echo "$PRINTINFO" ; exit $codeOK ;;
     --) shift ; break ;;
     *)  Usage ; exit $codeUNKNOWN ;;
   esac 
done


# Set SNMP connection paramaters
#
vSNMPGet=$( echo "/usr/bin/snmpget -O qv -v $PROTOCOL -c $COMMUNITY $HOSTNAME" );


# Check bad responses from snmpget tool
#
IsBadResponse () {
  local Response=$1
  #echo "DBG - IsBadResponse - var Response : $Response"
  BadResponses=("No Response" "Unknown host" "No Such Object")
  for r in "${BadResponses[@]}"
  do
    if [[ "${Response}" =~ "$r" ]] ; then
      return 0
    fi
  done
  return 1
}


# Get SLBox state
#
if [ "$MODE" = "uptime" ]; then

	vUptime=$( $vSNMPGet "1.3.6.1.4.1.45373.2.4" 2>&1 )

	if IsBadResponse "$vUptime"; then echo "SNMP Error: $vUptime"; exit $codeWARNING; fi

	if [ ! -z "$vUptime" ]; then
		vHRUptime=$( eval "echo $(date -ud "@$vUptime" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')" )
		echo -e "Uptime: $vHRUptime | 'uptime'=$vUptime;;;;"
		exit $codeOK
	fi

elif [ "$MODE" = "sensors" ]; then

        vHDDTemp=$( $vSNMPGet "1.3.6.1.4.1.45373.2.3" 2>&1 )

        if IsBadResponse "$vHDDTemp"; then echo "SNMP Error: $vHDDTemp"; exit $codeWARNING; fi

	# Warning threshold
	if [ ! -z "$vWARN" ]; then
	   vHDDTempWarn=$vWARN
	else
	   vHDDTempWarn=$vTempWarnDefault
	fi

	#Сritical threshold
        if [ ! -z "$vCRIT" ]; then
	   vHDDTempCrit=$vCRIT
        else
           vHDDTempCrit=$vTempCritDefault
        fi

        if [ ! -z "$vHDDTemp" ]; then
	 if [ "$vHDDTemp" -lt "$vHDDTempWarn" ]; then
                echo -e "OK: HDD Temperature Sensor - $vHDDTemp C | 'hddtemperature'=$vHDDTemp;$vHDDTempWarn;$vHDDTempCrit;;"
                exit $codeOK
	 elif [ "$vHDDTemp" -ge "$vHDDTempWarn" ] && [ "$vHDDTemp" -lt "$vHDDTempCrit" ]; then
                echo -e "High HDD Temperature - $vHDDTemp C | 'hddtemperature'=$vHDDTemp;$vHDDTempWarn;$vHDDTempCrit;;"
                exit $codeWARNING
         elif [ "$vHDDTemp" -ge "$vHDDTempCrit" ]; then
                echo -e "Critical HDD Temperature! - $vHDDTemp C | 'hddtemperature'=$vHDDTemp;$vHDDTempWarn;$vHDDTempCrit;;"
                exit $codeCRITICAL
	 fi
        fi

elif [ "$MODE" = "hdd" ]; then

        vHDDUsage=$( $vSNMPGet "1.3.6.1.4.1.45373.2.5" 2>&1 | tr -d '"')

	if IsBadResponse "$vHDDUsage"; then echo "SNMP Error: $vHDDUsage"; exit $codeWARNING; fi

        # Warning threshold
        if [ ! -z "$vWARN" ]; then
           vHDDUsageWarn=$vWARN
        else
           vHDDUsageWarn=$vHDDUsageWarnDefault
        fi

        #Сritical threshold
        if [ ! -z "$vCRIT" ]; then
           vHDDUsageCrit=$vCRIT
        else
           vHDDUsageCrit=$vHDDUsageCritDefault
        fi

        if [ ! -z "$vHDDUsage" ]; then
	  vHDDUsageFree=$( echo $vHDDUsage | cut -d' ' -f 2)
	  vHDDUsageMax=$( echo $vHDDUsage | cut -d' ' -f 1)
          vHDDUsageFreePct=$( printf '%.2f\n' $( echo "scale=2; $vHDDUsageFree*100/$vHDDUsageMax" | bc ) )
          vHDDUsageCurrPct=$( printf '%.2f\n' $( echo "100 - $vHDDUsageFreePct" | bc ) )
	  if [ $( echo "$vHDDUsageCurrPct < $vHDDUsageWarn" | bc ) -eq 1 ]; then
                echo -e "OK: HDD Usage - $vHDDUsageCurrPct % | 'hddusage'=$vHDDUsageCurrPct;$vHDDUsageWarn;$vHDDUsageCrit;;100"
                exit $codeOK
          elif [ $( echo "$vHDDUsageCurrPct >= $vHDDUsageWarn" | bc ) -eq 1 ] && [ $( echo "$vHDDUsageCurrPct < $vHDDUsageCrit" | bc ) -eq 1 ] ; then
                echo -e "High utilization of HDD capacity - $vHDDUsageCurrPct % | 'hddusage'=$vHDDUsageCurrPct;$vHDDUsageWarn;$vHDDUsageCrit;;100"
                exit $codeWARNING
	  elif [ $( echo "$vHDDUsageCurrPct >= $vHDDUsageCrit" | bc ) -eq 1 ]; then
                echo -e "HDD is full! - $vHDDUsageCurrPct % | 'hddusage'=$vHDDUsageCurrPct;$vHDDUsageWarn;$vHDDUsageCrit;;100"
                exit $codeCRITICAL
         fi
        fi

elif [ "$MODE" = "services" ]; then

	if [ "$vCHECKRecorder" -eq "0" ] && [ "$vCHECKCleaner" -eq "0" ] && [ "$vCHECKXCtl" -eq "0" ] && [ "$vCHECKFTPServer" -eq "0" ] && [ "$vCHECKSMDRAnalyzer" -eq "0" ]; then
          echo -e "No service selected to check... Please use additional options for 'services' mode"
          exit $codeUNKNOWN
	fi

	vSVCSumm=""; vSVCStatus="1"

	if [ "$vCHECKRecorder" -eq "1" ]; then
	   vSVCRecorder=$( $vSNMPGet "1.3.6.1.4.1.45373.2.7.1" 2>&1 )
	   if IsBadResponse "$vSVCRecorder"; then echo "SNMP Error: $vSVCRecorder"; exit $codeWARNING; fi
           if [ "$vSVCRecorder" -eq "1" ]; then
	      vSVCSumm=$vSVCSumm$( echo -e " \n + Recorder service running" );
	   elif [ "$vSVCRecorder" -eq "0" ]; then
	      vSVCSumm=$vSVCSumm$( echo -e " \n - Recorder service not running" );
	      vSVCStatus="0"
           fi
	fi

        if [ "$vCHECKCleaner" -eq "1" ]; then
           vSVCCleaner=$( $vSNMPGet "1.3.6.1.4.1.45373.2.7.2" 2>&1 )
	   if IsBadResponse "$vSVCCleaner"; then echo "SNMP Error: $vSVCCleaner"; exit $codeWARNING; fi
           if [ "$vSVCCleaner" -eq "1" ]; then
              vSVCSumm=$vSVCSumm$( echo -e " \n + Cleaner service running" );
           elif [ "$vSVCCleaner" -eq "0" ]; then
              vSVCSumm=$vSVCSumm$( echo -e " \n - Cleaner service not running!" );
              vSVCStatus="0"
           fi
	fi

        if [ "$vCHECKXCtl" -eq "1" ]; then
           vSVCXCtl=$( $vSNMPGet "1.3.6.1.4.1.45373.2.7.3" 2>&1 )
	   if IsBadResponse "$vSVCXCtl"; then echo "SNMP Error: $vSVCXCtl"; exit $codeWARNING; fi
           if [ "$vSVCXCtl" -eq "1" ]; then
              vSVCSumm=$vSVCSumm$( echo -e " \n + XCtl service running" );
           elif [ "$vSVCXCtl" -eq "0" ]; then
              vSVCSumm=$vSVCSumm$( echo -e " \n - XCtl service not running!" );
              vSVCStatus="0"
           fi
	fi

        if [ "$vCHECKFTPServer" -eq "1" ]; then
           vSVCFTPServer=$( $vSNMPGet "1.3.6.1.4.1.45373.2.7.4" 2>&1 )
	   if IsBadResponse "$vSVCFTPServer"; then echo "SNMP Error: $vSVCFTPServer"; exit $codeWARNING; fi
           if [ "$vSVCFTPServer" -eq "1" ]; then
              vSVCSumm=$vSVCSumm$( echo -e " \n + FTP Server service running" );
           elif [ "$vSVCFTPServer" -eq "0" ]; then
              vSVCSumm=$vSVCSumm$( echo -e " \n - FTP Server service not running!" );
              vSVCStatus="0"
           fi
	fi

        if [ "$vCHECKSMDRAnalyzer" -eq "1" ]; then
           vSVCSmdrAnalyzer=$( $vSNMPGet "1.3.6.1.4.1.45373.2.7.5" 2>&1 )
	   if IsBadResponse "$vSVCSmdrAnalyzer"; then echo "SNMP Error: $vSVCSmdrAnalyzer"; exit $codeWARNING; fi
           if [ "$vSVCSmdrAnalyzer" -eq "1" ]; then
              vSVCSumm=$vSVCSumm$( echo -e " \n + SMDR Analyzer service running" );
           elif [ "$vSVCSmdrAnalyzer" -eq "0" ]; then
              vSVCSumm=$vSVCSumm$( echo -e " \n - SMDR Analyzer service not running!" );
              vSVCStatus="0"
           fi
	fi

	if [ "$vSVCStatus" -eq "0" ]; then
	  echo -e "Some SLBox services are not working! \nCurrent state:$vSVCSumm"
	  exit $codeCRITICAL
	elif [ "$vSVCStatus" -eq "1" ]; then
	  echo -e "OK: SLBox Services are running \nCurrent state:$vSVCSumm"
	  exit $codeOK
	fi

fi
exit $codeUNKNOWN
