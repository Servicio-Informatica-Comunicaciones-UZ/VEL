#!/bin/bash


#Desmontamos las locales, ya que porceso salidas de ficheros con localización
LC_ALL=C


#Uso de memoria (%)
memUsage () {
    
    aux=$(free | grep -Ee "^Mem")
    
    totalMem=$(echo $aux | cut -d " " -f 2)
    usedMem=$(echo $aux | cut -d " " -f 3)
    diskCache=$(echo $aux | cut -d " " -f 7)
    
    usedMem=$(((usedMem-diskCache)*100/totalMem))
    
    echo -n "$usedMem"
    [ "$MODE" == "live" ] && echo -n %

    
    return 0;
}




#Uso de disco
# 1 -> ruta al dev de la partición o al punto de montaje
# 2 -> p -> imprime valor porcentual de uso   q -> imprime valor cuantitativo de uso
partitionUsage () {
    
    aux=$(df -h | grep "$1" | sed -re "s/ +/ /g")
    
    [ "$aux" == "" ] && return 1;
    
    
    [ "$2" == "p" ]  && ret=$(echo $aux | cut -d " " -f 5)
    
    [ "$2" == "q" ]  && ret=$(echo $aux | cut -d " " -f 3)/$(echo $aux | cut -d " " -f 2)
    
    echo -n "$ret" | sed -re "s/%//g"  
    
    [ "$MODE" == "live" -a  "$2" == "p" ] && echo -n %
    

    return 0;
}






#Indica si está recibiendo y enviando
# 1 -> tx: devuelve 0 si está transmitiendo rx: devuelve 0 si está recibiendo
# 2 -> interface (eth0, etc...)
networkStatus () {
        
    transmitting=$(echo "$STATGRAB" | grep net.$2.tx | sed -re "s/.*=[^0-9]*([0-9]+)[^0-9]*/\1/g")
    receiving=$(echo "$STATGRAB" | grep net.$2.rx | sed -re "s/.*=[^0-9]*([0-9]+)[^0-9]*/\1/g")
    
    
    #echo "-->$transmitting"
    #echo "-->$receiving"
    
    [ "$1" == "tx"  -a  "$transmitting" -gt 0 ] && return 0
    
    [ "$1" == "rx"  -a  "$receiving" -gt 0 ] && return 0
    
    return 1
}


currtimedate () {
    echo -n $(date +%c)
}


upTime () {
    echo -n $(uptime | sed -re "s/\s+/ /g" | sed -re "s/^.*up(.+), [0-9]+ users.*$/\1/g")
                               
}


idleTime () {
    #Primer valor: segundos encendido 
    onsecs=$(cat /proc/uptime | grep -Eoe "^[^ ]+")
    
    #Segundo valor: segundos inactivo
    idlesecs=$(cat /proc/uptime | sed -re  "s/^[^ ]+ (.+)/\1/g")
    
    echo -n $(python -c "print int(round($idlesecs*100/$onsecs,2))")
    [ "$MODE" == "live" ] && echo -n %
}




#Carga media del sistema en los últimos 1min, 5min y 15 min
loadAverage () {
    
    echo -n $(uptime | sed -re "s/.*load average: (.*)$/\1/g")
    
}




#Estadísticas de acceso a disco
# 1 -> unidad sda, sr0, etc
# 2 -> r -> tasa de lectura, en block/s    w -> tasa de escritura, en block/s
diskAccess () {

# -d mostrar estadísaticas de discos
# 1 -> intérvalo en que se dan las estadísticas, en segundos
# 2 -> número de reports (el primero es histórico desde el encendido, el segundo en el intérvalo de antes)
# quedarme con read/write blocks per sec.
#iostat -d "$1" 1 2 | nl | grep -Ee "^\s*5" | sed -re "s/\s+/ /g" | cut -d " " -f $field 


#5 read , 6 write
[ "$2" == "r" ] && field=5
[ "$2" == "w" ] && field=6

echo -n $( echo $IOSTAT | sed -re "s/\s+/ /g" | cut -d " " -f $field)" blocks/s"


}






cpuUsage () {
    
    #kernelTime=$(echo "$STATGRAB" | grep cpu.kernel | sed -re "s/.*=[^0-9]*([0-9]+)\..*/\1/g")
    #userTime=$(echo "$STATGRAB" | grep cpu.user | sed -re "s/.*=[^0-9]*([0-9]+)\..*/\1/g")
    #    
    #echo -n "$((kernelTime+userTime))%"  

    userTime=$(echo $MPSTAT | sed -re "s/\s+/ /g" | cut -d " " -f 3)
    niceTime=$(echo $MPSTAT | sed -re "s/\s+/ /g" | cut -d " " -f 4)
    kernTime=$(echo $MPSTAT | sed -re "s/\s+/ /g" | cut -d " " -f 5)

    #echo "user= $userTime"
    #echo "kern= $niceTime"
    #echo "nice= $kernTime"
    if [ "$userTime" != "" -a "$niceTime" != "" -a "$kernTime" != "" ] ; then
	echo -n $(python -c "print int(round($userTime+$niceTime+$kernTime,2))")%
    fi
}







#Gathers all data that needs time to perform differential polls
gatherData () {

#  $! -> pid of last subprocess
pids=""

baseFilename=/tmp/aux$RANDOM

#Ejecutarlo una sola vez si uso más estadísticas
    # -o realiza dos sondeos y devuelve los diferenciales 
    # -t 0.1 establece un tiempo de 0.1 segundos entre sondeos #Uso 1 porque si no falsea los resultados
    # -p devuelve los diferenciales de cpu en %
statgrab -p -t 1 -o > ${baseFilename}1  &
pids="$pids $!"



#Ejecutarlo una sola vez 
    # -b devuelve las estadísticas conjuntas de I/O para todos los devs de bloques
    # Se ejecuta un sondeo (en realidad dos, pero se muestra el diferencial), de un segundo
    # Aquí la media no es desde que se inició el sistema, sino desde que se inciió el sondeo. si hay uno sólo, equivalen.
sar -b 1 1 | grep Average > ${baseFilename}2 &
pids="$pids $!"


#Ejecutarlo una sola vez 
    #Obtiene el porcentaje de uso del procesador en este período (1 segundo)
mpstat 1 1 | grep Average > ${baseFilename}3 &
pids="$pids $!"




wait $pids





STATGRAB=$(cat  ${baseFilename}1)
IOSTAT=$(cat  ${baseFilename}2)
MPSTAT=$(cat  ${baseFilename}3)



rm -f  ${baseFilename}1
rm -f  ${baseFilename}2
rm -f  ${baseFilename}3




#echo $STATGRAB
#echo $IOSTAT
#echo $MPSTAT

}





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


# 1 -> ruta del dev a medir: ej. /dev/sda
#Devuelve el modelo de disco duro
hddModel () {

   
    line=$(/usr/sbin/hddtemp "$1" -u C 2>/dev/null)
    
    #Como no devuelve códigos de error, miramos que la salida acabe en una temperatura
    goodmsg=$(echo "$line" | grep -Ee "[0-9]+.*?C$")
    if [ "$goodmsg" == ""  ] ; then
	return 1;
    fi
    
    #Devolvemos el modelo de disco duro
    #echo -n $(echo "$line" | sed -re "s/[^:]+: (.+$)/\1/g" | sed -re "s/(.+):\s*[0-9]+\s*C$/\1/g")
    echo -n "$line" | cut -d ":" -f 2
    
    return 0

}



#Devuelve temperaturas para todos los sensores disponibles.
coreTemps () {
    data=$(/usr/local/bin/tempsensor.py temp 2>/dev/null)
    
    [ $? -ne 0  ] && return 1

    echo -n "$data"
    return 0
}

#Devuelve la velocidad de los ventiladores para los sensores disponibles
hugeMetalFans () {
    data=$(/usr/local/bin/tempsensor.py fan 2>/dev/null)
    
    [ $? -ne 0  ] && return 1

    echo -n "$data"
    return 0
}




listUSBs  () {

   USBDEVS=""
   usbs=$(ls /proc/scsi/usb-storage/ 2>/dev/null) 
   for f in $usbs
      do
      currdev=$(sginfo -l | sed -ne "s/.*=\([^ ]*\).*$f.*/\1/p")
      USBDEVS="$USBDEVS $currdev"
   done

   echo -n "$USBDEVS"
}

listHDDs () {
    
    drives=""
    
    usbs=''
#$$$$1    usbs=$(listUSBs)  #La llamada a sginfo -l peta totalmente mi sistema (debian etch stable), pero por suerte no la ubuntu lucid.

    for n in a b c d e f g h i j k l m n o p q r s t u v w x y z 
      do
      
      drivename=/dev/hd$n
      
      [ -e $drivename ] && drives="$drives $drivename"
      
      drivename=/dev/sd$n

      for usb in $usbs
	do
	#Si el drive name es un usb, pasa de él.
	[ "$drivename" == "$usb" ]   && continue 2
      done

      
      [ -e $drivename ] && drives="$drives $drivename"
      
    done
    
    for mdid in $(seq 0 99) ; do
	
	drivename=/dev/md$mdid
	
	[ -e $drivename ] && drives="$drives $drivename"
	
    done
    
    echo "$drives"
    
}


# 1 -> Drive
getPartitions () {

    dp=$(/sbin/fdisk -l "$1" 2>/dev/null)
    
    thisparts=""
    if [ "$dp" != "" ] 
	then
	thisparts=$(echo "$dp" | grep -Ee "^$1" | cut -d " " -f 1 )
    fi
    
    echo "$thisparts"
}



#List active eth interfaces
getInterfaces () {

    ifconfig |  grep eth | sed -re "s/\s+/ /g" | cut -d " " -f 1

}







######## Funcs para la recogida de estadísticas  ###############


#List all devs we have IO info from, excluding partitions 
getIODevList () {


    devsandparts=$(iostat -d | sed '1,3d'  | cut -d " " -f 1)
    
    
    usbs=''
#$$$$1    usbs=$(listUSBs)  #La llamada a sginfo -l peta totalmente mi sistema (debian etch stable), pero por suerte no la ubuntu lucid.
    
    currdev=""
    for dv in $devsandparts
      do
      
      for usb in $usbs
	do
	#Si el drive name es un usb, pasa de él.
	[ "$dv" == "$(basename $usb)" ]  && continue 2
      done
      
      if [ "$currdev" == "" ] ; then
	  currdev=$dv 
	  echo "$dv"
	  continue
      fi
      
      #echo "currdev: $currdev"

      #Miramos si el nombre de este dev-or-part es super-cadena del actual (es una partición) o no
      isPart=$(expr match "$dv" "\($currdev\)")

      #echo "isPart: $isPart"

      #Si no hay match es un dev distinto, no una part
      if [ "$isPart" == "" ] ; then
	  currdev=$dv 
	  echo "$dv"
	  continue	  
      fi
      
    done

}


# 1 -> dev name (not path)
# 2 -> r -> bloques totales leidos,    w -> bloques totales escritos 
getAbsoluteIO () {

    IOdata=$(iostat -d | sed '1,3d' | grep -Ee "^$1[^a-zA-Z0-9]" | sed -re "s/\s+/ /g")
     
    
    [ "$2" == "r" ] && (echo $IOdata | cut -d " " -f 5)  
    
    [ "$2" == "w" ] && (echo $IOdata | cut -d " " -f 6)  
}




#Devuelve los bytes Rx o Tx por una interfaz
# 1 -> Interface i:e: eth0
# 2 -> Get Received (rx) or Transmitted (tx) amount 
getAbsoluteNetwork () {

    data=$(statgrab net.$1.$2 2>/dev/null)

    [  "$data" == "" ] && return 1

    value=$(echo $data | grep "=" | sed -re "s/.*=\s+([0-9]+$)/\1/g")

    [  "$value" == "" ] && return 1

    echo "$value"

    return 0
}


loadAverage5min () {
    echo -n $(uptime | sed -re "s/.*load average: .*,\s+(.*),.*$/\1/g")
}



#Percentage of CPU used by apache since uptime
apacheCPUUsage () {
    dataline=$(apache2ctl fullstatus | grep -e "CPU load")

    [ "$dataline" == "" ] && echo -n "0"
    #en los gauge acepta floats en cualquier notación. en derivce y counter acepta sólo en notación .XXXX, no XX.XXX
    echo -n $(echo $dataline | sed -re 's/.*-\s+([^%]+)%\s+CPU.*/\1/g')   
}

#Percentage of Memory used by apache processes
apacheMemUsage () {

    memusageperprocess=$(ps ax -o pmem,comm | grep apache2 | cut -d " " -f 2)
    
    #Sumamos el uso de memoria de todas las instancias de apache
    acumMem=0.0; 

    for usedMem in $memusageperprocess ; do
	#echo "$acumMem+$usedMem"
	acumMem=$(python -c "print $acumMem+$usedMem")
	#echo "--->$acumMem"
    done

    echo -n $acumMem
}


#Lists HDDs that have temperature sensors
listSMARTHDDs () {

    currdisks=$(listHDDs)
    SMARTdisks=""
    if [ "$currdisks" != "" ] ; then
	
	for disk in $currdisks
	  do
	  #Si devuelve una temp, lo añadimos a la lista de discos con sensor
	  hddTemp $disk 2>&1 >/dev/null
	  [ "$?" -eq "0" ] && SMARTdisks="$SMARTdisks $disk"
	done
	
	[ "$SMARTdisks" == "" ] && return 1

	echo "$SMARTdisks"

    fi
    
    return 1
}




#Convert MB, GB or TB to kB (integer truncated value)
# 1-> value
toKiloBytes (){

 [ "$1" == "" ] && return 1

 python -c "
import re
factors={'kB':1, 'KB':1, 'mB':1024,'MB':1024,'gB':1024*1024,'GB':1024*1024,'tB':1024*1024*1024,'TB':1024*1024*1024}
num,unit = re.compile('([.0-9]+)\s([a-zA-Z]+)').findall('$1')[0]
print int(float(num)*factors[unit])
"
 
 return 0
}


#Kb transfered by server since uptime
apacheTransferedKb () {
    #La salida viene en unidades desde el KB hasta... el TB?
    inputHRvalue=$(apache2ctl fullstatus | grep -e "Total accesses" |sed -re "s/.*Total Traffic:\s+([.0-9]+.*$)/\1/g")
    
    toKiloBytes "$inputHRvalue"
}

#Number of petitions made to apache since uptime
apachePetitions () {
    apache2ctl fullstatus | grep -e "Total accesses" | sed -re "s/.*Total accesses:\s+([0-9]+).+/\1/g"
}












#### MAIN ####


LOGPATH="/media/crypStorage/rrds"
GRAPHPATH="/var/www/statgraphs"

LOGPATH="/root/test/" #!!!!1
GRAPHPATH="./"        #!!!!1



# 1 -> Modo 'live'         -> imprme tabla de estadísitcas para visualizar
#           'startLog'     -> realiza las operaciones de creación de las RDD de registro de estadístcas
#           'updateLog'    -> actualiza los valores en las RDD de registro de estadístcas
#           'updateGraphs' -> actualiza las gráficas generadas a partir de los datos de registro.
#           'installCron'  -> instala el actualizado en el cron.
#           'uninstallCron'-> desinstala el cron.

MODE="$1"

[ "$MODE" == "" ] && MODE=live






if [ "$MODE" == "installCron" ]
    then

    periods=$(seq 0 5 55)
    periods=$(echo $periods | sed -re "s/\s/,/g")
    
    echo -e "$periods * * * * root  /usr/local/bin/stats.sh updateLog >/dev/null 2>/dev/null; /usr/local/bin/stats.sh updateGraphs >/dev/null 2>/dev/null\n\n" >> /etc/crontab

fi



if [ "$MODE" == "uninstallCron" ]
    then
    
    sed -i -re "/^.*stats\.sh.*$/d" /etc/crontab
    
fi




getNumberOfCPUs () {
    echo -n $(ls /sys/devices/system/cpu/cpu[0-9]* -d | wc -l)
}

 
if [ "$MODE" == "startLog" ]
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
    labels=$(getIODevList)
    if [ "$labels" != "" ] ; then
	DSS=""
	for label in $labels
	  do
	  DSS="$DSS DS:${label}-r:DERIVE:600:0:U DS:${label}-w:DERIVE:600:0:U"
	done
	
	rrdtool create $LOGPATH/hddio.rrd --start $STDATE  --step 300 $DSS $RRAS    
    fi


    #RRD de I/O de red, por interfaz (2 entradas, tx y rx)
    labels=$(getInterfaces)
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
	    usageperc=$(partitionUsage $par p)
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
if [ "$MODE" == "updateLog" ]
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
    

    #I/O acumulada por HD/CD (2 entradas, r y w)
    DATA=""
    for iodev in $(getIODevList)
      do
      DATA="$DATA:$(getAbsoluteIO $iodev r):$(getAbsoluteIO $iodev w)"
    done
    [ "$DATA" != "" ] && rrdtool update $LOGPATH/hddio.rrd N$DATA    
    

    #I/O acumulada de ethernet, por interfaz (2 entradas, tx y rx)
    DATA=""
    for ethif in $(getInterfaces)
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
	    usageperc=$(partitionUsage $par p)
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





# 1 -> last (-1 - 14)
getNextRGBCode () {
    
    #echo "Asking for next to $1" >/dev/stderr

    local RGBCodes=(FF0000 00FF00 0000FF FF7700 00C000 330000 330066 666600  FF99CC 000000 FFCC00 99CCFF 339900 666666 9966FF FF0077)
    local len=${#RGBCodes[@]}
    local next=$(($1+1))
    #echo "next: $next len:$len">/dev/stderr
    if [ $next -lt  $len  ] ; then
	#echo "Color served: ${RGBCodes[$next]}" >/dev/stderr
	echo -n ${RGBCodes[$next]}
	return 0
    fi



    return 1
}







if [ "$MODE" == "updateGraphs" ]
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
    lastColour=-1
    if [ "$labels" != "" ] ; then
	SENSORS=""
	for label in $labels
	  do
	  colour=$(getNextRGBCode $lastColour)
	  lastColour=$((lastColour+1))
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
    labels=$(getIODevList)
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
    labels=$(getIODevList)
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
    labels=$(getInterfaces)
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
    labels=$(getInterfaces)
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
	    usageperc=$(partitionUsage $par p)
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

if [ "$MODE" == "live" ]
    then


gatherData



#Values

currtimedate; echo ""; echo ""
echo -n "Up: "; upTime; echo ""
echo -n "Idle: "; idleTime; echo ""
echo -n "Load 1m,5m,15m: "; loadAverage; echo ""
echo -n "CPU: "; cpuUsage; echo ""
echo -n "Memory: "; memUsage; echo ""



ethlist=$(getInterfaces)

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
    model=$(hddModel $disk)
    
    if [ "$model" == "" ] ; then     
	echo "*** $disk ***" 
    else
	echo "*** $disk ($model) ***"
    fi
    
    echo -n "Reads : "; diskAccess $disk r; echo ""
    echo -n "Writes: "; diskAccess $disk w; echo ""
    hdtemp=$(hddTemp $disk)
    [ $? -eq 0 ] && echo -n "Temperature: "; echo "$hdtemp"

    OUTPUT=""
    for par in  $(getPartitions  $disk) ; do  
	usageperc=$(partitionUsage $par p)
	if [ "$usageperc" != "" ] ;
	    then 
	    #echo -n "  $par: "; partitionUsage $par q; echo " ($usageperc)"
	    usageamount=$(partitionUsage $par q)
	    OUTPUT="$OUTPUT  $par: $usageamount ($usageperc)\n"

	fi
    done
    [ "$OUTPUT" != "" ] && echo -e "Disk Usage:\n$OUTPUT"

done


#Usage de los FS especiales
echo "Special Partitions Usage"
echo "------------------------"

#Uso del EncryptedFS	
usageperc=$(partitionUsage "/dev/mapper/*" p)
usageamount=$(partitionUsage "/dev/mapper/*" q)
echo "Encrypted Data Area: $usageamount ($usageperc)"

#Uso del RamFS
usageperc=$(partitionUsage "aufs" p)
usageamount=$(partitionUsage "aufs" q)
echo "RAM filesystem: $usageamount ($usageperc)"




fi





LC_ALL=""




#rrdtool create prueba.rrd --start $(date +%s) --step 300 DS:prueba:GAUGE:600:U:U RRA:AVERAGE:0.5:2:4
#rrdtool update prueba.rrd $((1279885468+600)):1.57e-5
#rrdtool dump prueba.rrd
#rrdtool graph -a PNG $FILENAME DEF:prueba1=prueba.rrd:prueba:AVERAGE LINE1:prueba1#0000FF:"condemor\l"
