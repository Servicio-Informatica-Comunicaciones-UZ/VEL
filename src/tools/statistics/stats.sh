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







#############
#  Methods  #
#############














# TODO Deleted tempsensor.py, find more standard alternative to get temperatures: sensors y hddtemp /dev/sda




# 1 -> ruta del dev a medir: ej. /dev/sda
#Devuelve la temperatura del disco duro
hddTemp () {
    
    line=$(/usr/sbin/hddtemp "$1" -u C 2>/dev/null)
    
    #Como no devuelve códigos de error, miramos que la salida acabe en una temperatura
    goodmsg=$(echo "$line" | grep -Ee "[0-9]+.*?C$")
    if [ "$goodmsg" == ""  ] ; then
	return 1;
    fi
    
    #Devolvemos la temperatura para mostrar, con unidades
    if [ "$MODE" == "live" ] ; then
	echo -n $(echo "$line" | sed -re "s/[^:]+: (.+$)/\1/g" | sed -re "s/.+:\s*([0-9]+\s*.*?C$)/\1/g")
    else
	#Solo el valor numérico, sin unidades, para la RRD
	echo -n $(echo "$line" | sed -re "s/[^:]+: (.+$)/\1/g" | sed -re "s/.+:\s*([0-9]+)\s*.*?C$/\1/g")
    fi
    
    return 0
}





#Return temperature for all CPU cores
coreTemps () {
    data=$(/usr/local/bin/tempsensor.py temp 2>/dev/null)
    
    [ $? -ne 0  ] && return 1

    echo -n "$data"
    return 0
}



































#### MAIN ####


LOGPATH="/media/crypStorage/rrds"
GRAPHPATH="/var/www/statgraphs"




#1 -> 'live':         print a human-readable set of current system metrics and health indicators
#     'start':        setup databases for stats registry and the visualization webapp
#     'updateLog':    register a new snapshot of the statistics in the database
#     'updateGraphs': regenerate graphics for the stats visualization webapp
#     'update':       updateLog + updateGraphs


#    [ "$MODE" == "live" ] && echo -n % in live mode, add the units at the end, not inside the functions



## TODO on update, if error, mail admin?

    # TODO Añadir auth básica web para las páginas de stats. usar la pwd del mgr web, actualizarla cada vez que se update el admin en la op correspondiente


  # TODO SEGUIR MAÑANA lo que se implemente aquí, que valga para ser llamado tal cual en el setup, así no hace falta reinstalar los sistemas ya desplegados para activar las stats

OP="$1"

[ "$OP" == "" ] && OP=live



## TODO make sure there is no output or expected error output







 
if [ "$OP" == "startLog" ]
    then

    #Calculamos el siguiente alineamiento de cinco minutos respecto a la hora actual
    dt=$(date +%s)
    dt=$((  dt+(300-(dt%300))  ))
    STDATE=$dt
    

    
    
#Generar Bases de datos RRD

    #Definimos los RRAs
    RRAS=""
    RRAS="$RRAS  RRA:LAST:0.5:1:12"       #Hourly  RRA
    RRAS="$RRAS  RRA:AVERAGE:0.5:12:24"   #Daily   RRA
    RRAS="$RRAS  RRA:AVERAGE:0.5:288:7"   #Weekly  RRA
    RRAS="$RRAS  RRA:AVERAGE:0.5:288:31"  #Monthly RRA
    
    
    
    #RRD de uso total de memoria del sistema (%)
    rrdtool create $LOGPATH/sysmem.rrd --start $STDATE  --step 300 DS:sysmem:GAUGE:600:0:100 $RRAS        
    
    
    #RRD de carga del sistema [0.0 - ?     idletime del procesador (%)
    #La carga es un valor entre 0 y el número de CPUs del sistema. (Un proc con 2 núcleos puede tener una carga entre 0 y 2)
    rrdtool create $LOGPATH/sysload.rrd --start $STDATE  --step 300 DS:sysload:GAUGE:600:0:$(getNumberOfCPUs) DS:sysidle:GAUGE:600:0:100 $RRAS    
    
    
    #RRD de temperaturas Core
    labels=$(/usr/local/bin/tempsensor.py temp list 2>/dev/null)
    if [ "$labels" != "" ] ; then
	DSS=""
	for label in $labels
	  do
	  DSS="$DSS DS:$label:GAUGE:600:U:U"
	done
	
	rrdtool create $LOGPATH/coretemperatures.rrd --start $STDATE  --step 300 $DSS $RRAS    
    fi
    
    
    #RRD de temperaturas de HD  
    labels=$(listSMARTHDDs)
    if [ "$labels" != "" ] ; then
	DSS=""
	for label in $labels
	  do
	  DSS="$DSS DS:$(basename $label):GAUGE:600:U:U"
	done
	
	rrdtool create $LOGPATH/hddtemperatures.rrd --start $STDATE  --step 300 $DSS $RRAS    
    fi
    
    
    
    #RRD de I/O acumulada por HD/CD (2 entradas, r y w)
    labels=$(listHDDs)
    if [ "$labels" != "" ] ; then
	DSS=""
	for label in $labels
	  do
	  DSS="$DSS DS:${label}-r:DERIVE:600:0:U DS:${label}-w:DERIVE:600:0:U"
	done
	
	rrdtool create $LOGPATH/hddio.rrd --start $STDATE  --step 300 $DSS $RRAS    
    fi


    #RRD de I/O de red, por interfaz (2 entradas, tx y rx)
    labels=$(getEthInterfaces)
    if [ "$labels" != "" ] ; then
	DSS=""
	for label in $labels
	  do
	  DSS="$DSS DS:${label}-tx:DERIVE:600:0:U DS:${label}-rx:DERIVE:600:0:U"
	done
	
	rrdtool create $LOGPATH/networkio.rrd --start $STDATE  --step 300 $DSS $RRAS    
    fi
    
    
    #RRD de accesos al servidor apache y Kb transmitidos
    rrdtool create $LOGPATH/apacheserved.rrd --start $STDATE  --step 300 DS:apachepets:GAUGE:600:0:U DS:apachekbs:GAUGE:600:0:U $RRAS    


    #RRD de uso de memoria y CPU del apache
    rrdtool create $LOGPATH/apacheload.rrd --start $STDATE  --step 300 DS:apachecpu:GAUGE:600:0:100 DS:apachemem:GAUGE:600:0:100 $RRAS    
	
    
    #RRD de uso las particiones de disco (en porcentaje)
    DSS=""
    for disk in $(listHDDs) ; do
	for par in  $(getPartitions  $disk) ; do  
	    #Sólo mostramos aquellas particiones que tienen sistema de ficheros válido (swap no, etc)
	    usageperc=$(partitionUsagePercent $par)
	    if [ "$usageperc" != "" ] ; then
		label=$(basename $par)
		DSS="$DSS DS:$label:GAUGE:600:0:100"
	    fi
	done
    done

    #Añadimos el uso del sistema de ficheros encriptado 
    DSS="$DSS DS:EncryptedFS:GAUGE:600:0:100"
    
    #Añadimos el uso del sistema de ficheros en RAM
    DSS="$DSS DS:RamFS:GAUGE:600:0:100"
    
    if [ "$DSS" != "" ] ; then
	rrdtool create $LOGPATH/diskusage.rrd --start $STDATE  --step 300 $DSS $RRAS    
    fi
    






fi


#Update RRDs' Data sources 
if [ "$OP" == "updateLog" ]
    then
    

    #Uso de memoria
    rrdtool update $LOGPATH/sysmem.rrd N:$(memUsage)
    
    #Carga del sistema y % del tiempo idle
    rrdtool update $LOGPATH/sysload.rrd N:$(loadAverage5min):$(idleTime)
    
    #Temperaturas core
    values=$(/usr/local/bin/tempsensor.py temp data 2>/dev/null)
    rrdtool update $LOGPATH/coretemperatures.rrd N:$(echo $values | sed -re "s/\s/:/g")

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
    
    [ "$DATA" != "" ] && rrdtool update $LOGPATH/hddtemperatures.rrd N$DATA
    

    #I/O acumulada por HD/CD (2 entradas, r y w)  # TODO cambiar por el diskReadRate y diskWriteRate
    DATA=""
    for iodev in $(listHDDs)
      do
      DATA="$DATA:$(getAbsoluteIO $iodev r):$(getAbsoluteIO $iodev w)"
    done
    [ "$DATA" != "" ] && rrdtool update $LOGPATH/hddio.rrd N$DATA    
    

    #I/O acumulada de ethernet, por interfaz (2 entradas, tx y rx)
    DATA=""
    for ethif in $(getEthInterfaces)
      do
      DATA="$DATA:$(getAbsoluteNetwork $ethif tx):$(getAbsoluteNetwork $ethif rx)"
    done
    [ "$DATA" != "" ] && rrdtool update $LOGPATH/networkio.rrd N$DATA    
    
    
    #Accesos al servidor apache y Kb transmitidos
    rrdtool update $LOGPATH/apacheserved.rrd N:$(apachePetitions):$(apacheTransferedKb)
    
    
    #Uso de memoria y CPU del apache
    rrdtool update $LOGPATH/apacheload.rrd N:$(apacheCPUUsage):$(apacheMemUsage)

       
    
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

    [ "$DATA" != "" ] && rrdtool update $LOGPATH/diskusage.rrd N$DATA
    
fi












if [ "$OP" == "updateGraphs" ]
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
    rrdtool graph $OPTS $HOURLY  $GRAPHPATH/sysmem-hourly.png  DEF:sysmem=$LOGPATH/sysmem.rrd:sysmem:LAST    LINE1:sysmem#FF0000:"System memory usage (%)"
    rrdtool graph $OPTS $DAILY   $GRAPHPATH/sysmem-daily.png   DEF:sysmem=$LOGPATH/sysmem.rrd:sysmem:AVERAGE LINE1:sysmem#FF0000:"System memory usage (%)"
    rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/sysmem-weekly.png  DEF:sysmem=$LOGPATH/sysmem.rrd:sysmem:AVERAGE LINE1:sysmem#FF0000:"System memory usage (%)"
    rrdtool graph $OPTS $MONTHLY $GRAPHPATH/sysmem-monthly.png DEF:sysmem=$LOGPATH/sysmem.rrd:sysmem:AVERAGE LINE1:sysmem#FF0000:"System memory usage (%)"

    #Carga del sistema
    rrdtool graph $OPTS $HOURLY  $GRAPHPATH/sysload-hourly.png  DEF:sysload=$LOGPATH/sysload.rrd:sysload:LAST    LINE1:sysload#FF0000:"System load (0-$(getNumberOfCPUs))"
    rrdtool graph $OPTS $DAILY   $GRAPHPATH/sysload-daily.png   DEF:sysload=$LOGPATH/sysload.rrd:sysload:AVERAGE LINE1:sysload#FF0000:"System load (0-$(getNumberOfCPUs))"
    rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/sysload-weekly.png  DEF:sysload=$LOGPATH/sysload.rrd:sysload:AVERAGE LINE1:sysload#FF0000:"System load (0-$(getNumberOfCPUs))"
    rrdtool graph $OPTS $MONTHLY $GRAPHPATH/sysload-monthly.png DEF:sysload=$LOGPATH/sysload.rrd:sysload:AVERAGE LINE1:sysload#FF0000:"System load (0-$(getNumberOfCPUs))"



    #Temperaturas Core
    
    #Para el hourly (por el LAST)
    labels=$(/usr/local/bin/tempsensor.py temp list 2>/dev/null)

    ## TODO reset the color sequence
    if [ "$labels" != "" ] ; then
	SENSORS=""
	for label in $labels
	  do
	  colour=$(getNextRGBCode)

	  defstr="DEF:$label=$LOGPATH/coretemperatures.rrd:$label:LAST  LINE1:$label#$colour:'$label(C)'"
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
	  defstr="DEF:$label=$LOGPATH/coretemperatures.rrd:$label:AVERAGE  LINE1:$label#$colour:'$label(C)'"
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
	  defstr="DEF:$label=$LOGPATH/hddtemperatures.rrd:$label:LAST  LINE1:$label#$colour:'$label(C)'"
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
	  defstr="DEF:$label=$LOGPATH/hddtemperatures.rrd:$label:AVERAGE  LINE1:$label#$colour:'$label(C)'"
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
	  defstrR="DEF:$labelr=$LOGPATH/hddio.rrd:$labelr:LAST  LINE1:$labelr#$colour:'$label(Blocks-read)'"
	  defstrW="DEF:$labelw=$LOGPATH/hddio.rrd:$labelw:LAST  LINE1:$labelw#$colour:'$label(Blocks-written)'"
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
	  defstrR="DEF:$labelr=$LOGPATH/hddio.rrd:$labelr:AVERAGE  LINE1:$labelr#$colour:'$label(Blocks-read)'"
	  defstrW="DEF:$labelw=$LOGPATH/hddio.rrd:$labelw:AVERAGE  LINE1:$labelw#$colour:'$label(Blocks-written)'"
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
	  defstrR="DEF:$labelr=$LOGPATH/networkio.rrd:$labelr:LAST  LINE1:$labelr#$colour:'$label(Bytes-Rx)'"
	  defstrW="DEF:$labelw=$LOGPATH/networkio.rrd:$labelw:LAST  LINE1:$labelw#$colour:'$label(Bytes-Tx)'"
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
	  defstrR="DEF:$labelr=$LOGPATH/networkio.rrd:$labelr:AVERAGE  LINE1:$labelr#$colour:'$label(Bytes-Rx)'"
	  defstrW="DEF:$labelw=$LOGPATH/networkio.rrd:$labelw:AVERAGE  LINE1:$labelw#$colour:'$label(Bytes-Tx)'"
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
	DEF:apachepets=$LOGPATH/apacheserved.rrd:apachepets:LAST    LINE1:apachepets#FF0000:"Petitions served by Apache" \
        DEF:apachekbs=$LOGPATH/apacheserved.rrd:apachekbs:LAST    LINE1:apachekbs#00FF00:"KB served by Apache"
    

    rrdtool graph $OPTS $DAILY   $GRAPHPATH/apachedata-daily.png   \
	DEF:apachepets=$LOGPATH/apacheserved.rrd:apachepets:AVERAGE    LINE1:apachepets#FF0000:"Petitions served by Apache" \
        DEF:apachekbs=$LOGPATH/apacheserved.rrd:apachekbs:AVERAGE    LINE1:apachekbs#00FF00:"KB served by Apache"
    rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/apachedata-weekly.png  \
	DEF:apachepets=$LOGPATH/apacheserved.rrd:apachepets:AVERAGE    LINE1:apachepets#FF0000:"Petitions served by Apache" \
        DEF:apachekbs=$LOGPATH/apacheserved.rrd:apachekbs:AVERAGE    LINE1:apachekbs#00FF00:"KB served by Apache"
    rrdtool graph $OPTS $MONTHLY $GRAPHPATH/apachedata-monthly.png \
	DEF:apachepets=$LOGPATH/apacheserved.rrd:apachepets:AVERAGE    LINE1:apachepets#FF0000:"Petitions served by Apache" \
        DEF:apachekbs=$LOGPATH/apacheserved.rrd:apachekbs:AVERAGE    LINE1:apachekbs#00FF00:"KB served by Apache"


    #Uso de memoria y CPU del apache
    rrdtool graph $OPTS $HOURLY  $GRAPHPATH/apacheresusage-hourly.png  \
	DEF:apachecpu=$LOGPATH/apacheload.rrd:apachecpu:LAST    LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
        DEF:apachemem=$LOGPATH/apacheload.rrd:apachemem:LAST    LINE1:apachemem#00FF00:"Memory used by Apache (%)"

    rrdtool graph $OPTS $DAILY   $GRAPHPATH/apacheresusage-daily.png   \
	DEF:apachecpu=$LOGPATH/apacheload.rrd:apachecpu:AVERAGE    LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
        DEF:apachemem=$LOGPATH/apacheload.rrd:apachemem:AVERAGE    LINE1:apachemem#00FF00:"Memory used by Apache (%)"
    rrdtool graph $OPTS $WEEKLY  $GRAPHPATH/apacheresusage-weekly.png  \
	DEF:apachecpu=$LOGPATH/apacheload.rrd:apachecpu:AVERAGE    LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
        DEF:apachemem=$LOGPATH/apacheload.rrd:apachemem:AVERAGE    LINE1:apachemem#00FF00:"Memory used by Apache (%)"
    rrdtool graph $OPTS $MONTHLY $GRAPHPATH/apacheresusage-monthly.png \
	DEF:apachecpu=$LOGPATH/apacheload.rrd:apachecpu:AVERAGE    LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
        DEF:apachemem=$LOGPATH/apacheload.rrd:apachemem:AVERAGE    LINE1:apachemem#00FF00:"Memory used by Apache (%)"


    
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
	  defstr="DEF:$label=$LOGPATH/diskusage.rrd:$label:LAST  LINE1:$label#$colour:'$label(%-in-use)'"
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
	  defstr="DEF:$label=$LOGPATH/diskusage.rrd:$label:AVERAGE  LINE1:$label#$colour:'$label(%-in-use)'"
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

if [ "$OP" == "live" ]
    then


gatherTimeDifferentialMetrics   2> /dev/null



#Values

currentDateTime; echo ""; echo ""
echo -n "Up: "; upTime; echo ""
echo -n "Idle: "; idleTime; echo ""
echo -n "Load 1m,5m,15m: "; loadAverage; echo ""
echo -n "CPU: "; processorUsage; echo ""
echo -n "Memory: "; memUsage; echo ""



ethlist=$(getEthInterfaces)

for eth in $ethlist
  do
  echo -n "Interface $eth Transmitting: "; 
  if $(networkStatus tx $eth) ; 
      then  
      echo -n "Yes"; 
  else 
      echo -n "No"  
  fi;
  echo ""
  echo -n "Interface $eth Receiving:    "; 
  if $(networkStatus rx $eth) ; 
      then  
      echo -n "Yes"; 
      else
      echo -n "No" 
  fi; 
  echo ""
done

echo ""


coreTemps=$(coreTemps)
if [ $? -eq 0 ]
    then
    echo -e "*** System Temperature sensors: ***";
    echo "$coreTemps"
    echo ""
fi

fanspeed=$(hugeMetalFans)
if [ $? -eq 0 ]
    then
    echo -e "*** Fan Speeds: ***";
    echo "$fanspeed"
fi

echo ""

for disk in $(listHDDs) ; do

    
	echo "*** $disk ***" 
    
    echo -n "Reads : "; diskReadRate  $disk; echo ""
    echo -n "Writes: "; diskWriteRate $disk; echo ""
    hdtemp=$(hddTemp $disk)
    [ $? -eq 0 ] && echo -n "Temperature: "; echo "$hdtemp"

    OUTPUT=""
    for par in  $(getPartitions  $disk) ; do  
	usageperc=$(partitionUsagePercent $par)
	if [ "$usageperc" != "" ] ;
	    then 
	    usageamount=$(partitionUsageAbsolute $par q)
	    OUTPUT="$OUTPUT  $par: $usageamount ($usageperc)\n"

	fi
    done
    [ "$OUTPUT" != "" ] && echo -e "Disk Usage:\n$OUTPUT"

done


#Usage de los FS especiales
echo "Special Partitions Usage"
echo "------------------------"

#Uso del EncryptedFS	
usageperc=$(partitionUsagePercent "/dev/mapper/*")
usageamount=$(partitionUsageAbsolute "/dev/mapper/*")
echo "Encrypted Data Area: $usageamount ($usageperc)"

#Uso del RamFS
usageperc=$(partitionUsagePercent "aufs")
usageamount=$(partitionUsageAbsolute "aufs")
echo "RAM filesystem: $usageamount ($usageperc)"




fi





LC_ALL=""




#rrdtool create prueba.rrd --start $(date +%s) --step 300 DS:prueba:GAUGE:600:U:U RRA:AVERAGE:0.5:2:4
#rrdtool update prueba.rrd $((1279885468+600)):1.57e-5
#rrdtool dump prueba.rrd
#rrdtool graph -a PNG $FILENAME DEF:prueba1=prueba.rrd:prueba:AVERAGE LINE1:prueba1#0000FF:"condemor\l"


