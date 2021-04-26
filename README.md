## About

**check_snmp_stc_slbox** - Icinga Plugin Script (Check Command). 

It get **STC Smart Logger Box** device current state from SNMP v1/2c data

PreReq: **snpmget** tool
Tested on **Debian GNU/Linux 10.8 (Buster)** with **snmpget 5.7.3** and **Icinga r2.12.3-1**
This plugin must be compatible with **Nagios**, but has not been tested.

Put here: /usr/lib/nagios/plugins/check_snmp_stc_slbox.sh


## Usage

Options:

```
Usage: /usr/lib/nagios/plugins/check_snmp_stc_slbox.sh [OPTIONS]

Option   GNU long option        Meaning
------   ---------------        -------
 -H      --hostname             Host name, IP Address. Required option.

 -P      --protocol             SNMP protocol version. 
                                Possible values: '1','2c'. 
                                Required option.

 -C      --community            SNMPv1/2c community string for SNMP communication 
                                (for example,'public')
                                Required option.

 -m      --mode                 Plugin modes. 
                                Possible values: 'uptime','sensors','hdd','services'
                                Required option.

 -w      --warning              Warning threshold. 
                                The value is used only with modes 'sensors' and 'hdd'
                                In 'sensors' mode, the value sets the temperature 
                                warning threshold in degrees Celsius. 
                                Default value(C): 45
                                In 'hdd' mode, the value sets the warning threshold 
                                for the use of disk capacity in percent.
                                Default value(%): 95

 -c      --critical             Сritical threshold. 
                                The value is used only with modes 'sensors' and 'hdd'.
                                In 'sensors' mode, the value sets the temperature critical 
                                threshold in degrees Celsius.
                                Default value(C): 50
                                In 'hdd' mode, the value sets the warning threshold 
                                for the use of disk capacity in percent.
                                Default value(%): 99

 -R     --check-recorder        Check voice recording service 'Recorder' state.
                                If the 'Recorder' service is stopped, 
                                phonogram recording does not work.
                                The option is used only with 'services' mode. 
                                The option is not enabled by default.

 -Z     --check-cleaner         Check voice records management service 'Cleaner' state.
                                If the 'Cleaner' service is stopped, 
                                deleting outdated phonograms does not work.
                                The option is used only with 'services' mode. 
                                The option is not enabled by default.

 -X     --check-xctl            Check control protocol service 'xctl' state.
                                'xctl' is the device control protocol that checks 
                                the communication between the base board,
                                mezzanine and SLBox software.
                                The option is used only with 'services' mode. 
                                The option is not enabled by default.

 -F     --check-ftpserver       Check 'ftp_server' service state.
                                FTP Server service is used for remote access to the phonograms.
                                The option is used only with 'services' mode. 
                                The option is not enabled by default.

 -S     --check-smdranalyzer    Check 'SmdrAnalyzer' service state.
                                The SmdrAnalyzer service is used if the device has an STC-H597 mezzanine 
                                (to work with the digital stream E1).
                                In this case, the service processes additional data on phone 
                                calls received from the PBX in the SMDR/CDR format.
                                The option is used only with 'services' mode. 
                                The option is not enabled by default.

 -q      --help                 Show this message
 -v      --version              Print version information and exit

```

Example for **hdd** mode:

```
$ ../check_snmp_stc_slbox.sh --mode=hdd --warning='95' --critical='98' \
--hostname='slbox-01.holding.com' --protocol='2c' --community='public'  

```
Icinga Director integration manual (in Russian):

[Исследование возможностей мониторинга регистраторов речевой информации STC Smart Logger BOX и плагин check_snmp_stc_slbox для базового мониторинга в Icinga](https://blog.it-kb.ru/2021/04/26/)
