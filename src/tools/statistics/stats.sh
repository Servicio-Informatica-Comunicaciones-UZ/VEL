#!/bin/bash


#Common functions for privileged and unprivileged scripts.
. /usr/local/bin/common.sh

#Common functions for privileged scripts
. /usr/local/bin/privileged-common.sh

#Auxiliary functions for the statistics monitor
. /usr/local/bin/stats-common.sh

#Functions to gather statistics
. /usr/local/bin/stats-probes.sh





###############
#  Constants  #
###############


#Location of the roudn robin databses for statistics
DBPATH="/media/crypStorage/rrds"

#Location where the stats graphs will be generated
GRAPHPATH="/var/www/statgraphs"




#############
#  Methods  #
#############



#For the live stats operation
printNetworkStats () {
    
    local ethlist=$(getEthInterfaces)
    
    for eth in $ethlist
    do
        local status=0
        status=$(networkStatus $eth)
        
        local tx="No"
        ((status & 2 )) && tx="Yes"
        
        local rx="No"
        ((status & 1 )) && rx="Yes"
        
        
        echo "Interface $eth Transmitting: $tx";
        echo "Interface $eth Receiving:    $rx"; 
    done
}



#For the live stats operation
printCoreTemperatures () {
    
    local coreList=$(getListOfCPUs)
    local coreNum=1
    for core in coreList
    do
        echo "$core: "$(coreTemp $coreNum)" C"
        coreNum=$((coreNum+1))
    done
}



#For the live stats operation
#1 -> partition path
#2 -> (optional) tag name
printPartitionUsage () {
    
    local tag="$1"
    [ "$2" != "" ] && tag="$2"
    
    local usageperc=$(partitionUsagePercent $1)"%"
    local usageamount=$(partitionUsageAbsolute $1)
	   if [ "$usageperc" != "" ] ; then 
	       echo "$tag: $usageamount ($usageperc)"
	   fi
}









##################
#  Main program  #
##################

#Operations:
#1 -> 'live':         print a human-readable set of current system metrics and health indicators
#     'start':        setup databases for stats registry and the visualization webapp
#     'updateLog':    register a new snapshot of the statistics in the database
#     'updateGraphs': regenerate graphics for the stats visualization webapp
#     'update':       updateLog + updateGraphs


OPERATION="$1"
#Default
[ "$OPERATION" == "" ] && OPERATION="live"






#Prints a screen with several statistics and system health indicators,
#for human reading
if [ "$OPERATION" == "live" ]
then


    gatherTimeDifferentialMetrics   2> /dev/null # TODO only on live or also on updateLog?


    
    ### Print stats screen ###
    
    #System
    echo $(currentDateTime)
    echo ""
    echo $"Up:     "$(upTime)
    echo $"Idle:   "$(idleTime)"%"
    echo ""
    echo $"CPU:    "$(processorUsage)"%"
    echo $"Memory: "$(memUsage)"%"
    echo $"Load 1m,5m,15m: "$(loadAverage)
    echo ""
    
    #Network
    printNetworkStats
    echo ""
    
    #Core temperature
    echo "***"$"CORE TEMPERATURES"":";
    printCoreTemperatures
    echo ""
    
    #Disk information
    for disk in $(listHDDs)
    do    
	       echo "*** $disk ("$(hddTemp $disk)" C)***"
        echo $"Reads : "$(diskReadRate  $disk)$" blocks/s"
        echo $"Writes: "$(diskWriteRate $disk)$" blocks/s"
        
        for par in  $(getPartitionsForDrive $disk)
        do  
	           printPartitionUsage $par
        done
        echo ""
    done
    
    #Special FS usage information
    echo $"Special Filesystems information"
    echo  "-------------------------------"
    #Encrypted FS	
    printPartitionUsage "/dev/mapper/$MAPNAME"  $"Encrypted Data Area"
    #RAM FS
    printPartitionUsage "aufs"  $"RAM filesystem"
    
    exit 0
fi













#SEGUIR


#Setup statistics databases and web application
if [ "$OPERATION" == "start" ]
then
    
    #Calculate start date (next 5-minute alignment from now)
    now=$(date +%s)
    STDATE=$(( now+(300-(now%300)) ))
    
    
    #Define round robin archives
    RRAS=""    
    RRAS="$RRAS  RRA:LAST:0.5:1:12"       #Hourly  RRA
    RRAS="$RRAS  RRA:AVERAGE:0.5:12:24"   #Daily   RRA
    RRAS="$RRAS  RRA:AVERAGE:0.5:288:7"   #Weekly  RRA
    RRAS="$RRAS  RRA:AVERAGE:0.5:288:31"  #Monthly RRA
    
    
    #Create RRD: Memory usage (%)
    rrdtool create $DBPATH/sysmem.rrd --start $STDATE --step 300 \
            DS:sysmem:GAUGE:600:0:100   $RRAS        
    
    
    #Create RRD: System load [0.0 - number_of_cores], processor idle time (%)
    rrdtool create $DBPATH/sysload.rrd --start $STDATE --step 300 \
            DS:sysload:GAUGE:600:0:$(getNumberOfCPUs) \
            DS:sysidle:GAUGE:600:0:100    $RRAS
    
    
    #Create RRD: Core temperature (ºC)
    labels=$(getListOfCPUs)
    dataSources=""
    if [ "$labels" != "" ] ; then
        for label in $labels ; do
	           dataSources="$dataSources    DS:$label:GAUGE:600:U:U"
	       done
	       rrdtool create $DBPATH/coretemperatures.rrd --start $STDATE --step 300 \
                $dataSources    $RRAS    
    fi
    
    
    #Create RRD: Disk drives temperatures  
    labels=$(listSMARTHDDs)
	   dataSources=""
    if [ "$labels" != "" ] ; then
        for label in $labels ; do
	           dataSources="$dataSources DS:$(basename $label):GAUGE:600:U:U"
	       done
	       rrdtool create $DBPATH/hddtemperatures.rrd --start $STDATE --step 300 \
                $dataSources    $RRAS    
    fi
    
    
    #Create RRD: Disk IO acumulada por HD/CD (2 entradas, r y w)  ## SEGUIR usar diskreadrate y writerate, ahora es una medida puntual, no un acumulado, revisar definición de todas las datasources de todas las rrd.
    labels=$(listHDDs)
    if [ "$labels" != "" ] ; then
	       dataSources=""
	       for label in $labels
	       do
	           dataSources="$dataSources DS:${label}-r:DERIVE:600:0:U DS:${label}-w:DERIVE:600:0:U"
	       done
	       
	       rrdtool create $DBPATH/hddio.rrd --start $STDATE  --step 300 $dataSources $RRAS    
    fi


    #RRD de I/O de red, por interfaz (2 entradas, tx y rx)  ## TODO Usar valor acumulad de tx y rx? supongo que con cada reboot/ifdown se reiniciará este acumulado. ver man rrdtool para ver cómo reaccionará a una caída del acumulado.
    labels=$(getEthInterfaces)
    if [ "$labels" != "" ] ; then
	       dataSources=""
	       for label in $labels
	       do
	           dataSources="$dataSources DS:${label}-tx:DERIVE:600:0:U DS:${label}-rx:DERIVE:600:0:U"
	       done
	       
	       rrdtool create $DBPATH/networkio.rrd --start $STDATE  --step 300 $dataSources $RRAS    
    fi
    
    
    #RRD de accesos al servidor apache y Kb transmitidos
    rrdtool create $DBPATH/apacheserved.rrd --start $STDATE  --step 300 DS:apachepets:GAUGE:600:0:U DS:apachekbs:GAUGE:600:0:U $RRAS    


    #RRD de uso de memoria y CPU del apache
    rrdtool create $DBPATH/apacheload.rrd --start $STDATE  --step 300 DS:apachecpu:GAUGE:600:0:100 DS:apachemem:GAUGE:600:0:100 $RRAS    
	   
    
    #RRD de uso las particiones de disco (en porcentaje)
    dataSources=""
    for disk in $(listHDDs) ; do
	       for par in  $(getPartitions  $disk) ; do  
	           #Sólo mostramos aquellas particiones que tienen sistema de ficheros válido (swap no, etc)
	           usageperc=$(partitionUsagePercent $par)
	           if [ "$usageperc" != "" ] ; then
		              label=$(basename $par)
		              dataSources="$dataSources DS:$label:GAUGE:600:0:100"
	           fi
	       done
    done

    #Añadimos el uso del sistema de ficheros encriptado 
    dataSources="$dataSources DS:EncryptedFS:GAUGE:600:0:100"
    
    #Añadimos el uso del sistema de ficheros en RAM
    dataSources="$dataSources DS:RamFS:GAUGE:600:0:100"
    
    if [ "$dataSources" != "" ] ; then
	       rrdtool create $DBPATH/diskusage.rrd --start $STDATE  --step 300 $dataSources $RRAS    
    fi
    






fi


#Update RRDs' Data sources 
if [ "$OPERATION" == "updateLog" ]
then
    

    #Uso de memoria
    rrdtool update $DBPATH/sysmem.rrd N:$(memUsage)
    
    #Carga del sistema y % del tiempo idle
    rrdtool update $DBPATH/sysload.rrd N:$(loadAverage5min):$(idleTime)
    
    #Temperaturas core
    values=$(/usr/local/bin/tempsensor.py temp data 2>/dev/null) ## ESto está devolviendo una lista separada por espacios con las temperaturas de cada core, sin más
    rrdtool update $DBPATH/coretemperatures.rrd N:$(echo $values | sed -re "s/\s/:/g")

    #Temperaturas de HDD
    DATA=""
    for disk in $(listSMARTHDDs) ; do
	       hdtemp=$(hddTemp $disk)
	       if [ $? -eq 0 ]
	       then
	           DATA="$DATA:$hdtemp"
	       else
	           DATA="$DATA:U" #Si el dato está añadido pero no da resultados, escribir unknown
	       fi
    done
    
    [ "$DATA" != "" ] && rrdtool update $DBPATH/hddtemperatures.rrd N$DATA
    

    #I/O acumulada por HD/CD (2 entradas, r y w)  # TODO cambiar por el diskReadRate y diskWriteRate
    DATA=""
    for iodev in $(listHDDs)
    do
        DATA="$DATA:$(getAbsoluteIO $iodev r):$(getAbsoluteIO $iodev w)"
    done
    [ "$DATA" != "" ] && rrdtool update $DBPATH/hddio.rrd N$DATA    
    

    #I/O acumulada de ethernet, por interfaz (2 entradas, tx y rx)
    DATA=""
    for ethif in $(getEthInterfaces)
    do
        DATA="$DATA:$(getAbsoluteNetwork $ethif tx):$(getAbsoluteNetwork $ethif rx)"
    done
    [ "$DATA" != "" ] && rrdtool update $DBPATH/networkio.rrd N$DATA    
    
    
    #Accesos al servidor apache y Kb transmitidos
    rrdtool update $DBPATH/apacheserved.rrd N:$(apachePetitions):$(apacheTransferedKb)
    
    
    #Uso de memoria y CPU del apache
    rrdtool update $DBPATH/apacheload.rrd N:$(apacheCPUUsage):$(apacheMemUsage)

    
    
    #Uso las particiones de disco (en porcentaje)
    DATA=""
    for disk in $(listHDDs) ; do
	       for par in  $(getPartitions  $disk) ; do  
	           usageperc=$(partitionUsagePercent $par)
	           if [ "$usageperc" != "" ] ; then
		              #echo "usage: $usageperc"
		              DATA="$DATA:$usageperc"
	           fi
	       done
    done
    
    #Uso del EncryptedFS
    DATA="$DATA:"$(df -h | sed -re "s/\s+/ /g" | grep -Ee "^/dev/mapper" | cut -d " " -f 5 | sed -re "s/%//g")

    #Uso del RamFS
    DATA="$DATA:"$(df -h | sed -re "s/\s+/ /g" | grep -Ee "^aufs.*\/$" | cut -d " " -f 5 | sed -re "s/%//g")


    #echo "diskusage: $DATA";

    [ "$DATA" != "" ] && rrdtool update $DBPATH/diskusage.rrd N$DATA
    
fi












if [ "$OPERATION" == "updateGraphs" ]
then
    
    #Crea el dir de los gráficos
    [ -e "$GRAPHPATH"  ] || mkdir -p "$GRAPHPATH"
    chmod go-r "$GRAPHPATH" 2>/dev/null

    #Opciones comunes generales
    OPTS=" -a PNG --width 600 --height 200 "


    
    #Opciones de rango de datos
    HOURLY="--start now-1h --end now --step 300"     # Datos cada 5 min
    DAILY="--start now-24h --end now --step 3600"    # Datos cada hora
    WEEKLY="--start now-7d --end now --step 86400"   # Datos cada 24 horas
    MONTHLY="--start now-31d --end now --step 86400" # Datos cada 24 horas

    #Uso de memoria del sistema
    rrdtool graph $OPTS $HOURLY  $GRAPHPATH/sysmem-hourly.png  DEF:sysmem=$DBPATH/sysmem.rrd:sysmem:LAST    LINE1:sysmem#FF0000:"System memory usage (%)"
    rrdtool graph $OPTS $DAILY   $GRAPHPATH/sysmem-daily.png   DEF:sysmem=$DBPATH/sysmem.rrd:sysmem:AVERAGE LINE1:sysmem#FF0000:"System memory usage (%)"
    rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/sysmem-weekly.png  DEF:sysmem=$DBPATH/sysmem.rrd:sysmem:AVERAGE LINE1:sysmem#FF0000:"System memory usage (%)"
    rrdtool graph $OPTS $MONTHLY $GRAPHPATH/sysmem-monthly.png DEF:sysmem=$DBPATH/sysmem.rrd:sysmem:AVERAGE LINE1:sysmem#FF0000:"System memory usage (%)"

    #Carga del sistema
    rrdtool graph $OPTS $HOURLY  $GRAPHPATH/sysload-hourly.png  DEF:sysload=$DBPATH/sysload.rrd:sysload:LAST    LINE1:sysload#FF0000:"System load (0-$(getNumberOfCPUs))"
    rrdtool graph $OPTS $DAILY   $GRAPHPATH/sysload-daily.png   DEF:sysload=$DBPATH/sysload.rrd:sysload:AVERAGE LINE1:sysload#FF0000:"System load (0-$(getNumberOfCPUs))"
    rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/sysload-weekly.png  DEF:sysload=$DBPATH/sysload.rrd:sysload:AVERAGE LINE1:sysload#FF0000:"System load (0-$(getNumberOfCPUs))"
    rrdtool graph $OPTS $MONTHLY $GRAPHPATH/sysload-monthly.png DEF:sysload=$DBPATH/sysload.rrd:sysload:AVERAGE LINE1:sysload#FF0000:"System load (0-$(getNumberOfCPUs))"
    
    
    
    #Temperaturas Core
    
    #Para el hourly (por el LAST)
    labels=$(/usr/local/bin/tempsensor.py temp list 2>/dev/null)
    
    ## TODO reset the color sequence
    if [ "$labels" != "" ] ; then
	       SENSORS=""
	       for label in $labels
	       do
	           colour=$(getNextRGBCode)

	           defstr="DEF:$label=$DBPATH/coretemperatures.rrd:$label:LAST  LINE1:$label#$colour:'$label(C)'"
	           SENSORS="$SENSORS $defstr"
	       done
	       
	       rrdtool graph $OPTS $HOURLY  $GRAPHPATH/coretemps-hourly.png  $SENSORS
    fi
    
    #Para el resto
    labels=$(/usr/local/bin/tempsensor.py temp list 2>/dev/null)
    lastColour=-1
    if [ "$labels" != "" ] ; then
	       SENSORS=""
	       for label in $labels
	       do
	           colour=$(getNextRGBCode $lastColour)
	           lastColour=$((lastColour+1))
	           defstr="DEF:$label=$DBPATH/coretemperatures.rrd:$label:AVERAGE  LINE1:$label#$colour:'$label(C)'"
	           SENSORS="$SENSORS $defstr"
	       done
	       
	       rrdtool graph $OPTS $DAILY   $GRAPHPATH/coretemps-daily.png   $SENSORS
	       rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/coretemps-weekly.png  $SENSORS
	       rrdtool graph $OPTS $MONTHLY $GRAPHPATH/coretemps-monthly.png $SENSORS
    fi

    

    #RRD de temperaturas de HD  

    #Para el hourly (por el LAST)
    labels=$(listSMARTHDDs)
    lastColour=-1
    if [ "$labels" != "" ] ; then
	       SENSORS=""
	       for label in $labels
	       do
	           label=$(basename $label)
	           colour=$(getNextRGBCode $lastColour)
	           lastColour=$((lastColour+1))
	           defstr="DEF:$label=$DBPATH/hddtemperatures.rrd:$label:LAST  LINE1:$label#$colour:'$label(C)'"
	           SENSORS="$SENSORS $defstr"
	       done
	       
	       rrdtool graph $OPTS $HOURLY  $GRAPHPATH/hddtemps-hourly.png  $SENSORS
    fi
    
    #Para el resto
    labels=$(listSMARTHDDs)
    lastColour=-1
    if [ "$labels" != "" ] ; then
	       SENSORS=""
	       for label in $labels
	       do
	           label=$(basename $label)
	           colour=$(getNextRGBCode $lastColour)
	           lastColour=$((lastColour+1))
	           defstr="DEF:$label=$DBPATH/hddtemperatures.rrd:$label:AVERAGE  LINE1:$label#$colour:'$label(C)'"
	           SENSORS="$SENSORS $defstr"
	       done
	       
	       rrdtool graph $OPTS $DAILY   $GRAPHPATH/hddtemps-daily.png   $SENSORS
	       rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/hddtemps-weekly.png  $SENSORS
	       rrdtool graph $OPTS $MONTHLY $GRAPHPATH/hddtemps-monthly.png $SENSORS
    fi


    
    
    #I/O acumulada por HD/CD (2 entradas, r y w)

    #Para el hourly (por el LAST)
    labels=$(listHDDs)
    lastColour=-1
    if [ "$labels" != "" ] ; then
	       SENSORSR=""
	       SENSORSW=""
	       for label in $labels
	       do
	           colour=$(getNextRGBCode $lastColour)
	           lastColour=$((lastColour+1))
	           labelr=$label-r
	           labelw=$label-w
	           defstrR="DEF:$labelr=$DBPATH/hddio.rrd:$labelr:LAST  LINE1:$labelr#$colour:'$label(Blocks-read)'"
	           defstrW="DEF:$labelw=$DBPATH/hddio.rrd:$labelw:LAST  LINE1:$labelw#$colour:'$label(Blocks-written)'"
	           SENSORSR="$SENSORSR $defstrR"
	           SENSORSW="$SENSORSW $defstrW"
	       done
	       
	       rrdtool graph $OPTS $HOURLY  $GRAPHPATH/hddior-hourly.png  $SENSORSR
	       rrdtool graph $OPTS $HOURLY  $GRAPHPATH/hddiow-hourly.png  $SENSORSW
    fi
    
    #Para el resto
    labels=$(listHDDs)
    lastColour=-1
    if [ "$labels" != "" ] ; then
	       SENSORSR=""
	       SENSORSW=""
	       for label in $labels
	       do
	           colour=$(getNextRGBCode $lastColour)
	           lastColour=$((lastColour+1))
	           labelr=$label-r
	           labelw=$label-w
	           defstrR="DEF:$labelr=$DBPATH/hddio.rrd:$labelr:AVERAGE  LINE1:$labelr#$colour:'$label(Blocks-read)'"
	           defstrW="DEF:$labelw=$DBPATH/hddio.rrd:$labelw:AVERAGE  LINE1:$labelw#$colour:'$label(Blocks-written)'"
	           SENSORSR="$SENSORSR $defstrR"
	           SENSORSW="$SENSORSW $defstrW"
	       done

	       
	       rrdtool graph $OPTS $DAILY   $GRAPHPATH/hddior-daily.png   $SENSORSR
	       rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/hddior-weekly.png  $SENSORSR
	       rrdtool graph $OPTS $MONTHLY $GRAPHPATH/hddior-monthly.png $SENSORSR
	       rrdtool graph $OPTS $DAILY   $GRAPHPATH/hddiow-daily.png   $SENSORSW
	       rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/hddiow-weekly.png  $SENSORSW
	       rrdtool graph $OPTS $MONTHLY $GRAPHPATH/hddiow-monthly.png $SENSORSW
    fi

    
    
    #Para el hourly (por el LAST)
    labels=$(getEthInterfaces)
    lastColour=-1
    if [ "$labels" != "" ] ; then
	       SENSORSR=""
	       SENSORSW=""
	       for label in $labels
	       do
	           colour=$(getNextRGBCode $lastColour)
	           lastColour=$((lastColour+1))
	           labelr=$label-rx
	           labelw=$label-tx
	           defstrR="DEF:$labelr=$DBPATH/networkio.rrd:$labelr:LAST  LINE1:$labelr#$colour:'$label(Bytes-Rx)'"
	           defstrW="DEF:$labelw=$DBPATH/networkio.rrd:$labelw:LAST  LINE1:$labelw#$colour:'$label(Bytes-Tx)'"
	           SENSORSR="$SENSORSR $defstrR"
	           SENSORSW="$SENSORSW $defstrW"
	       done
	       
	       rrdtool graph $OPTS $HOURLY  $GRAPHPATH/networkiorx-hourly.png  $SENSORSR
	       rrdtool graph $OPTS $HOURLY  $GRAPHPATH/networkiotx-hourly.png  $SENSORSW	
    fi
    
    #Para el resto
    labels=$(getEthInterfaces)
    lastColour=-1
    if [ "$labels" != "" ] ; then
	       SENSORSR=""
	       SENSORSW=""
	       for label in $labels
	       do
	           colour=$(getNextRGBCode $lastColour)
	           lastColour=$((lastColour+1))
	           labelr=$label-rx
	           labelw=$label-tx
	           defstrR="DEF:$labelr=$DBPATH/networkio.rrd:$labelr:AVERAGE  LINE1:$labelr#$colour:'$label(Bytes-Rx)'"
	           defstrW="DEF:$labelw=$DBPATH/networkio.rrd:$labelw:AVERAGE  LINE1:$labelw#$colour:'$label(Bytes-Tx)'"
	           SENSORSR="$SENSORSR $defstrR"
	           SENSORSW="$SENSORSW $defstrW"
	       done
	       
	       rrdtool graph $OPTS $DAILY   $GRAPHPATH/networkiorx-daily.png   $SENSORSR
	       rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/networkiorx-weekly.png  $SENSORSR
	       rrdtool graph $OPTS $MONTHLY $GRAPHPATH/networkiorx-monthly.png $SENSORSR
	       rrdtool graph $OPTS $DAILY   $GRAPHPATH/networkiotx-daily.png   $SENSORSW
	       rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/networkiotx-weekly.png  $SENSORSW
	       rrdtool graph $OPTS $MONTHLY $GRAPHPATH/networkiotx-monthly.png $SENSORSW

    fi


    #Accesos al servidor apache y Kb transmitidos
    rrdtool graph $OPTS $HOURLY  $GRAPHPATH/apachedata-hourly.png  \
	           DEF:apachepets=$DBPATH/apacheserved.rrd:apachepets:LAST    LINE1:apachepets#FF0000:"Petitions served by Apache" \
            DEF:apachekbs=$DBPATH/apacheserved.rrd:apachekbs:LAST    LINE1:apachekbs#00FF00:"KB served by Apache"
    

    rrdtool graph $OPTS $DAILY   $GRAPHPATH/apachedata-daily.png   \
	           DEF:apachepets=$DBPATH/apacheserved.rrd:apachepets:AVERAGE    LINE1:apachepets#FF0000:"Petitions served by Apache" \
            DEF:apachekbs=$DBPATH/apacheserved.rrd:apachekbs:AVERAGE    LINE1:apachekbs#00FF00:"KB served by Apache"
    rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/apachedata-weekly.png  \
	           DEF:apachepets=$DBPATH/apacheserved.rrd:apachepets:AVERAGE    LINE1:apachepets#FF0000:"Petitions served by Apache" \
            DEF:apachekbs=$DBPATH/apacheserved.rrd:apachekbs:AVERAGE    LINE1:apachekbs#00FF00:"KB served by Apache"
    rrdtool graph $OPTS $MONTHLY $GRAPHPATH/apachedata-monthly.png \
	           DEF:apachepets=$DBPATH/apacheserved.rrd:apachepets:AVERAGE    LINE1:apachepets#FF0000:"Petitions served by Apache" \
            DEF:apachekbs=$DBPATH/apacheserved.rrd:apachekbs:AVERAGE    LINE1:apachekbs#00FF00:"KB served by Apache"


    #Uso de memoria y CPU del apache
    rrdtool graph $OPTS $HOURLY  $GRAPHPATH/apacheresusage-hourly.png  \
	           DEF:apachecpu=$DBPATH/apacheload.rrd:apachecpu:LAST    LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
            DEF:apachemem=$DBPATH/apacheload.rrd:apachemem:LAST    LINE1:apachemem#00FF00:"Memory used by Apache (%)"

    rrdtool graph $OPTS $DAILY   $GRAPHPATH/apacheresusage-daily.png   \
	           DEF:apachecpu=$DBPATH/apacheload.rrd:apachecpu:AVERAGE    LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
            DEF:apachemem=$DBPATH/apacheload.rrd:apachemem:AVERAGE    LINE1:apachemem#00FF00:"Memory used by Apache (%)"
    rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/apacheresusage-weekly.png  \
	           DEF:apachecpu=$DBPATH/apacheload.rrd:apachecpu:AVERAGE    LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
            DEF:apachemem=$DBPATH/apacheload.rrd:apachemem:AVERAGE    LINE1:apachemem#00FF00:"Memory used by Apache (%)"
    rrdtool graph $OPTS $MONTHLY $GRAPHPATH/apacheresusage-monthly.png \
	           DEF:apachecpu=$DBPATH/apacheload.rrd:apachecpu:AVERAGE    LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
            DEF:apachemem=$DBPATH/apacheload.rrd:apachemem:AVERAGE    LINE1:apachemem#00FF00:"Memory used by Apache (%)"


    
    #Uso las particiones de disco
    labels=""
    for disk in $(listHDDs) ; do
	       for par in  $(getPartitions  $disk) ; do 
	           usageperc=$(partitionUsagePercent $par)
	           if [ "$usageperc" != "" ] ; then
		              label=$(basename $par)
		              labels="$labels $label"
	           fi
	       done
    done

    labels="$labels EncryptedFS"
    labels="$labels RamFS"

    
    #Para el hourly (por el LAST)
    lastColour=-1
    if [ "$labels" != "" ] ; then
	       PUSAGE=""
	       for label in $labels
	       do
	           colour=$(getNextRGBCode $lastColour)
	           lastColour=$((lastColour+1))
	           defstr="DEF:$label=$DBPATH/diskusage.rrd:$label:LAST  LINE1:$label#$colour:'$label(%-in-use)'"
	           PUSAGE="$PUSAGE $defstr"
	       done
	       
	       rrdtool graph $OPTS $HOURLY  $GRAPHPATH/diskusage-hourly.png  $PUSAGE
    fi
    
    #Para el resto
    lastColour=-1
    if [ "$labels" != "" ] ; then
	       PUSAGE=""
	       for label in $labels
	       do
	           colour=$(getNextRGBCode $lastColour)
	           lastColour=$((lastColour+1))
	           defstr="DEF:$label=$DBPATH/diskusage.rrd:$label:AVERAGE  LINE1:$label#$colour:'$label(%-in-use)'"
	           PUSAGE="$PUSAGE $defstr"
	       done
	       
	       rrdtool graph $OPTS $DAILY   $GRAPHPATH/diskusage-daily.png   $PUSAGE
	       rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/diskusage-weekly.png  $PUSAGE
	       rrdtool graph $OPTS $MONTHLY $GRAPHPATH/diskusage-monthly.png $PUSAGE
    fi

	   



    #Generamos las páginas HTML con las gráficas


    #Poner títulos para cada gráfica
    PNGfiles=$(cat $0 | grep  -oEe "[-_.0-9a-zA-Z]+\.png")



    pages="hourly daily weekly monthly"

    for page in $pages ; do

        filepath="$GRAPHPATH/$page.html"

        pagePNGs=$(echo $PNGfiles | grep -oEe "[-._0-9a-zA-Z]+-$page.png")    
        
        echo "<html> <head><meta http-equiv=\"REFRESH\" content=\"300\"><title>Server Statistics</title></head><body>" > $filepath
        
        echo "<h1>Server Statistics</h1><h3>-Detail period: $page</h3>Last Update: $(date)" >> $filepath

        echo '<br/><br/>' >> $filepath
        
        for pg in $pages ; do
	           [ $pg != $page ] && echo ' <a href="'$pg'.html">'$pg'</a>  ' >> $filepath
	           [ $pg == $page ] && echo "$pg  " >> $filepath
        done
        
        echo '<br/><br/>' >> $filepath
        
        
        for png in $pagePNGs ; do
	           

	           if [ -s "$GRAPHPATH/$png" ] 
	           then
	               echo '<br/><br/><img src="'$png'"/>' >> $filepath
	           fi
	           
        done
        
        echo "</body></html>" >> $filepath
        
        
    done






    ############
    #SEGUIR:
    #Publicar las gráficas en el servidor web (generar código en html y volcarlo en el dir de graphs)
    #Probar a ver
    #  -f '<IMG SRC="/img/%s" WIDTH="%lu" HEIGHT="%lu" ALT="Demo">' ?  
    #  -E sloped graph curves
    ##############



    
fi





if [ "$OPERATION" == "update" ]
then
    :
fi




LC_ALL=""





# TODO Añadir auth básica web para las páginas de stats. usar la pwd del mgr web, actualizarla cada vez que se update el admin en la op correspondiente

# TODO SEGUIR MAÑANA lo que se implemente aquí, que valga para ser llamado tal cual en el setup, así no hace falta reinstalar los sistemas ya desplegados para activar las stats

## TODO make sure there is no output or expected error output





#rrdtool create prueba.rrd --start $(date +%s) --step 300 DS:prueba:GAUGE:600:U:U RRA:AVERAGE:0.5:2:4
#rrdtool update prueba.rrd $((1279885468+600)):1.57e-5
#rrdtool dump prueba.rrd
#rrdtool graph -a PNG $FILENAME DEF:prueba1=prueba.rrd:prueba:AVERAGE LINE1:prueba1#0000FF:"condemor\l"
