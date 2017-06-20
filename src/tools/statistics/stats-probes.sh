#!/bin/bash


#All the functions returning system statistics go here




#Gathers all data that needs a period of time to calculate the
#metrics. All gatherings are executed in paralllel and results
#exported in variables:
# STATGRAB
# IOSTAT
# MPSTAT
#When using the result variables, put them between double quotes
gatherTimeDifferentialMetrics () {
    
    #Store here the pid of all the parallel processes to be
    #synchronized
    local pids=""
    local suffix=$RANDOM
    
    
    #Gets several statistics
    # -o:     probes twice and returns the differential 
    # -t 0.5: lapse between probings of 0.5 seconds (>=1 for accuracy)
    # -p:     return CPU diffreentials as a percentage
    statgrab -p -t 1 -o > /tmp/statgrab.$suffix &
    pids="$pids $!"
    
    #Gets aggregated block devices read and write rates
    # -b: return aggregated IO statistics for all block devices
    # -d: return IO statistics per block device
    # -p: print dev name for each block device instead of internal name
    #  1: time lapse between probings, 1 second 
    #  1: number of probings, 1 (besides the initial one, of course)
    #(as there is only one probe, average row equals the single probe row)
    sar -dp 1 1 | grep Average > /tmp/iostat.$suffix &
    pids="$pids $!"

    #Gets processor usage stats
    #  1: time lapse between probings, 1 second 
    #  1: number of probings, 1 (besides the initial one, of course)
    #Obtiene el porcentaje de uso del procesador en este período (1 segundo)
    mpstat 1 1 | grep Average > /tmp/mpstat.$suffix &
    pids="$pids $!"
    
    
    #Sync all the processes
    wait $pids
    
    
    #Get the data from the subprocesses
    STATGRAB=$(cat /tmp/statgrab.$suffix)
    IOSTAT=$(cat /tmp/iostat.$suffix)
    MPSTAT=$(cat /tmp/mpstat.$suffix)
    
    #Remove the buffer files
    rm -f /tmp/statgrab.$suffix 2>/dev/null
    rm -f /tmp/iostat.$suffix 2>/dev/null
    rm -f /tmp/mpstat.$suffix 2>/dev/null
    
    return 0
}





#Show how long has been the system up since last startup, in human
#readable form.
upTime () {
    echo -n $(uptime | sed -re "s/\s+/ /g" \
                     | sed -re "s/^.*up(.+), [0-9]+ users.*$/\1/g")
    return 0
}





#Percentage of the time system has been idle (to give a view of the
#system load) On multi-core systems, this percentage may be >100%
idleTime () {
    #First value: seconds since system startup 
    local onsecs=$(cat /proc/uptime | grep -Eoe "^[^ ]+")
    
    #Second value: senconds system has been idle
    local idlesecs=$(cat /proc/uptime | sed -re  "s/^[^ ]+ (.+)/\1/g")
    
    echo -n $(python -c "print int(round($idlesecs*100/$onsecs,2))")
    return 0
}





#Prints average system load in the last 1min, 5min and 15 min
loadAverage () {
    echo -n $(uptime | sed -re "s/.*load average: (.*)$/\1/g")
    return 0   
}





#Prints average system load in the last 5min
loadAverage5min () {
    echo -n $(uptime | sed -re "s/.*load average: .*,\s+(.*),.*$/\1/g")
}





#Prints the percentage of used system memory.
memUsage () {
    
    local data=$(free | grep -Ee "^Mem")
    
    local totalMem=$(echo $data  | cut -d " " -f 2)
    local usedMem=$(echo $data   | cut -d " " -f 3)
    local buffers=$(echo $data   | cut -d " " -f 6)
    local diskCache=$(echo $data | cut -d " " -f 7)
    
    local usedMem=$(((usedMem-diskCache-buffers)*100/totalMem))
    
    echo -n "$usedMem"
    return 0
}





#Disk usage for all available partitions, absolute value for used
#space and total with human-readable units
#1 -> partition dev path or mount path
partitionUsageAbsolute () {
    
    local data=$(df -h | grep "$1" | sed -re "s/ +/ /g")
    [ "$data" == "" ] && return 1
    
    local usage=$(echo $data | cut -d " " -f 3)/$(echo $data | cut -d " " -f 2)
    
    echo -n "$usage"
    return 0
}





#Disk usage for all available partitions, percentage value with no
#units
#1 -> partition dev path or mount path
partitionUsagePercent () {
    
    local data=$(df -h | grep "$1" | sed -re "s/ +/ /g")
    [ "$data" == "" ] && return 1
    
    local usage=$(echo $data | cut -d " " -f 5 | sed -re "s/%//g")
    
    echo -n "$usage"
    return 0
}





#Will print the disk read rate in blocks/s at the moment
#1 -> Disk drive name ('sda', 'sr0', etc.) or path
#WARNING: Relays on the call to gatherTimeDifferentialMetrics
diskReadRate () {
    [ "$1" == "" ] && return 1
    drive=$(basename "$1")
    echo -n $( echo "$IOSTAT" | grep "$drive" | sed -re "s/\s+/ /g" | cut -d " " -f 4)
    return 0
}





#Will print the disk write rate in blocks/s at the moment
#1 -> Disk drive name ('sda', 'sr0', etc.) or path
#WARNING: Relays on the call to gatherTimeDifferentialMetrics
diskWriteRate () {
        [ "$1" == "" ] && return 1
    drive=$(basename "$1")
    echo -n $( echo "$IOSTAT" | grep "$drive" | sed -re "s/\s+/ /g" | cut -d " " -f 5)
    return 0
}




#Will print the precentage of time processor is being used
#WARNING: Relays on the call to gatherTimeDifferentialMetrics
processorUsage () {
    
    #Capture types of usage to aggregate
    local userTime=$(echo $MPSTAT | sed -re "s/\s+/ /g" | cut -d " " -f 3)
    local niceTime=$(echo $MPSTAT | sed -re "s/\s+/ /g" | cut -d " " -f 4)
    local kernTime=$(echo $MPSTAT | sed -re "s/\s+/ /g" | cut -d " " -f 5)
    
    #Add the values and print the result (using python because there are floats)
	   echo -n $(python -c "print int(round($userTime+$niceTime+$kernTime,2))")
    return 0
}





#Percentage of CPU currently used by apache processes at the moment
apacheProcessorUsage () {
    
    #Get percentage of CPU usage for all apache processes
    local data=$(ps ax -o pcpu,comm | grep apache2 | cut -d " " -f 2)
    
    #Sum all the percentages (as value is float, we use python)
    sum=0.0;
    for row in $data ; do
        sum=$(python -c "print $sum+$row")
	   done
    
    echo -n $sum
    return 0
}




#Percentage of Memory used by apache processes
apacheMemoryUsage () {
    
    #Get percentage of memory usage for all apache processes
    local data=$(ps ax -o pmem,comm | grep apache2 | cut -d " " -f 2)
    
    #Sum all the percentages (as value is float, we use python)
    local sum=0.0;
    for row in $data ; do
        sum=$(python -c "print $sum+$row")
	   done
    
    echo -n $sum
    return 0
}





#Return a two bit flag to mark whether there is network transmission
#and reception
# 1 -> interface name
# RETURN:
#  Tx Rx Value
#  0  0    0
#  0  1    1
#  1  0    2
#  1  1    3
networkStatus () {
    
    local tx=$(echo "$STATGRAB" | grep net.$1.tx | sed -re "s/.*=[^0-9]*([0-9]+)[^0-9]*/\1/g")
    local rx=$(echo "$STATGRAB" | grep net.$1.rx | sed -re "s/.*=[^0-9]*([0-9]+)[^0-9]*/\1/g")

    local ret=0
    [ "$tx" -gt 0 ] &&  ret=$((ret|2))
    [ "$rx" -gt 0 ] &&  ret=$((ret|1))
    
    return $ret
}





#Print the accumulated number of received or transmitted bytes through
#an ethernet interface
#1-> Interface name (i.e. eth0)
#2-> 'rx' to get the received value, 'tx' to get the transmitted value
getAbsoluteNetwork () {
    
    local data=$(statgrab net.$1.$2 2>/dev/null)
    [  "$data" == "" ] && return 1
    
    local value=$(echo $data | grep "=" | sed -re "s/.*=\s+([0-9]+$)/\1/g")
    [  "$value" == "" ] && return 1

    echo -n "$value"
    return 0
}





#Get temperature in Celsius degrees of a SMART enabled disk drive
#1 -> path of the device (i.e. /dev/sda)
hddTemp () {
    
    local data=$(/usr/sbin/hddtemp "$1" -u C 2>/dev/null)
    
    #Check output correctness (as hddtemp always returns zero)
    if (! echo "$data" | grep -Ee "[0-9]+.*?C$")
    then
	       return 1
    fi
    
    #Print the temperature (no units)
	   echo -n $(echo "$data" | sed -re "s/^.*: ([-0-9]+).*C$/\1/g")
    return 0
}





#Return temperature for a given CPU core in Celsius degrees
#1 -> number of core (according to the order of the list returned by getListOfCPUs)
coreTemp () {
    
    local core="$1"
    
    #Get the line with the selected core temperature
    local data=$(sensors | grep -Ee "Core" | nl | grep -Ee "^\s*$core" )
    
    #Return the temperature (no units)
    echo -n $(echo "$data" | sed -re "s/^[^:]*:\s*[-+]?([.0-9]+).*$/\1/g")
    return 0
}
