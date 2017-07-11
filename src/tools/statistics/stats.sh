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
DBPATH=$DATAPATH"/rrds"


#Location where the stats graphs will be generated
#WARNING: if this path was to be altered, keep consistency at
#default-ssl.conf
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






#Create the statistics round robin databases
createStatsDatabases () {
    
    #Calculate start date (next 5-minute alignment from now)
    local now=$(date +%s)
    local stdate=$(( now+(300-(now%300)) ))
    
    
    #Define round robin archives, the hourly one will keep the last
    #literal 5-minute sample, the rest will average the previous
    #values up to a day, a week or a month
    local rrArchives=""    
    rrArchives="$rrArchives  RRA:LAST:0.5:1:12"       #Hourly  RRA
    rrArchives="$rrArchives  RRA:AVERAGE:0.5:12:24"   #Daily   RRA
    rrArchives="$rrArchives  RRA:AVERAGE:0.5:288:7"   #Weekly  RRA
    rrArchives="$rrArchives  RRA:AVERAGE:0.5:288:31"  #Monthly RRA
    
    
    #Create RRD: Memory usage (%)
    rrdtool create $DBPATH/sysmem.rrd --start $stdate --step 300 \
            DS:sysmem:GAUGE:600:0:100   $rrArchives        
    
    
    #Create RRD: System load [0.0 - number_of_cores], processor idle time (%)
    rrdtool create $DBPATH/sysload.rrd --start $stdate --step 300 \
            DS:sysload:GAUGE:600:0:U \
            DS:sysidle:GAUGE:600:0:U    $rrArchives
    
    
    #Create RRD: Core temperature (ºC)
    local labels=$(getListOfCPUs)
    local dataSources=""
    if [ "$labels" != "" ] ; then
        for label in $labels ; do
	           dataSources="$dataSources    DS:$label:GAUGE:600:U:U"
	       done
	       rrdtool create $DBPATH/coretemperatures.rrd --start $stdate --step 300 \
                $dataSources    $rrArchives    
    fi
    
    
    #Create RRD: Disk drives temperatures  
    labels=$(listSMARTHDDs)
	   dataSources=""
    if [ "$labels" != "" ] ; then
        for label in $labels ; do
	           dataSources="$dataSources DS:$(basename $label):GAUGE:600:U:U"
	       done
	       rrdtool create $DBPATH/hddtemperatures.rrd --start $stdate --step 300 \
                $dataSources    $rrArchives    
    fi
    
    
    #Create RRD: Disk IO rate. Sample measure, 2 data sources per
    #drive (read and write)
    labels=$(listHDDs)
    dataSources=""
    if [ "$labels" != "" ] ; then
	       for label in $labels ; do
	           dataSources="$dataSources  DS:"$(basename $label)"-read:GAUGE:600:0:U
                                       DS:"$(basename $label)"-write:GAUGE:600:0:U"
	       done
	       rrdtool create $DBPATH/hddio.rrd --start $stdate  --step 300 \
                $dataSources    $rrArchives    
    fi
    
    
    #Create RRD: Network I/O accumulated transfer. 2 data sources per
    #network interface (should only be one but well), tx and rx
    labels=$(getEthInterfaces)
    dataSources=""
    if [ "$labels" != "" ] ; then
	       for label in $labels ; do
	           dataSources="$dataSources  DS:${label}-tx:DERIVE:600:0:U
                                       DS:${label}-rx:DERIVE:600:0:U"
	       done
	       rrdtool create $DBPATH/networkio.rrd --start $stdate  --step 300 \
                $dataSources    $rrArchives    
    fi
    
    
    #Create RRD: Apache web server Memory and CPU usage
    rrdtool create $DBPATH/apacheload.rrd --start $stdate  --step 300 \
            DS:apachecpu:GAUGE:600:0:100 \
            DS:apachemem:GAUGE:600:0:100   $rrArchives    
	   
    
    #Create RRD: storage usage per partition (percentage)
    dataSources=""
    for disk in $(listHDDs) ; do
	       for par in  $(getPartitionsForDrive  $disk) ; do  
	          	usageperc=$(partitionUsagePercent $par)
	           if [ "$usageperc" != "" ] ; then
		              label=$(basename $par)
		              dataSources="$dataSources   DS:$label:GAUGE:600:0:100"
	           fi
	       done
    done
    
    #Also, add encrypted filesystem usage 
    dataSources="$dataSources   DS:EncryptedFS:GAUGE:600:0:100"
    
    #And the RAM filesystem
    dataSources="$dataSources   DS:RamFS:GAUGE:600:0:100"
    
    if [ "$dataSources" != "" ] ; then
	       rrdtool create $DBPATH/diskusage.rrd --start $stdate  --step 300 \
                $dataSources    $rrArchives    
    fi
    
    return 0
}






#Capture values from the probes and add them to the statistics
#databases
updateLog () {
    local values=""
    local value=""
    
    #Memory usage (%)
    rrdtool update $DBPATH/sysmem.rrd  N:$(memUsage)
    
    #System load (int) and idle time (%)
    rrdtool update $DBPATH/sysload.rrd  N:$(loadAverage5min):$(idleTime)
    
    
    #CPU cores temperature (C degrees)
    values="N"
    for core in $(getListOfCPUs)
    do
        value=$(coreTemp $core  2>>$STATLOG)
        [ "$value" == "" ] && value="U" #If none, input 'Unknown'
        values="$values:$value"
    done
    [ "$values" != "N" ] && rrdtool update $DBPATH/coretemperatures.rrd "$values"
    
    
    #SMART HDDs temperature (C degrees)
    values="N"
    for disk in $(listSMARTHDDs)
    do
        value=$(hddTemp $disk  2>>$STATLOG)
        [ "$value" == "" ] && value="U" #If none, input 'Unknown'
        values="$values:$value"
    done
    [ "$values" != "N" ] && rrdtool update $DBPATH/hddtemperatures.rrd "$values"
    
    
    #Sampled HDD read/write rate (blocks/s)
    values="N"
    for disk in $(listHDDs)
    do
        values="$values":$(diskReadRate $disk):$(diskWriteRate $disk)
    done
    [ "$values" != "N" ] && rrdtool update $DBPATH/hddio.rrd "$values"
    

    #Accumulated Ethernet I/O per interface (bytes)
    values="N"
    for ethif in $(getEthInterfaces)
    do
        values="$values":$(getAbsoluteNetwork $ethif tx):$(getAbsoluteNetwork $ethif rx)
    done
    [ "$values" != "N" ] && rrdtool update $DBPATH/networkio.rrd "$values"
    
    
    #Apache CPU (%) and memory (%) usage
    rrdtool update $DBPATH/apacheload.rrd  N:$(apacheProcessorUsage):$(apacheMemoryUsage)
    
    
    #Disk usage per partition (%)
    values="N"
    for disk in $(listHDDs)
    do
	       for par in  $(getPartitionsForDrive  $disk)
        do  
	           value=$(partitionUsagePercent $par)
	           [ "$value" != "" ] && values="$values:$value"
	       done
    done
    #Encrypted filesystem usage
    values="$values:"$(partitionUsagePercent "$MAPNAME")
    #RAM filesystem usage
    values="$values:"$(partitionUsagePercent aufs)
    
    [ "$values" != "N" ] && rrdtool update $DBPATH/diskusage.rrd  "$values"

    return 0
}








#Builds all the graphs from the stored statistics
generateGraphs () {
    
    #General graphinc options and executable
    local rrdgraph="rrdtool graph -a PNG --width 600 --height 200 "
    
    
    #Time detail options
    local hourly="--start now-1h --end now --step 300"     # Every 5 min
    local daily="--start now-24h --end now --step 3600"    # Every hour
    local weekly="--start now-7d --end now --step 86400"   # Every 24 hours
    local monthly="--start now-31d --end now --step 86400" # Every 24 hours
    
    
    
    #Generate graphs: system memory
    $rrdgraph $hourly  $GRAPHPATH/sysmem-hourly.png  DEF:sysmem=$DBPATH/sysmem.rrd:sysmem:LAST \
              LINE1:sysmem#FF0000:"System memory usage (%)"
    $rrdgraph $daily   $GRAPHPATH/sysmem-daily.png   DEF:sysmem=$DBPATH/sysmem.rrd:sysmem:AVERAGE \
              LINE1:sysmem#FF0000:"System memory usage (%)"
    $rrdgraph $weekly  $GRAPHPATH/sysmem-weekly.png  DEF:sysmem=$DBPATH/sysmem.rrd:sysmem:AVERAGE \
              LINE1:sysmem#FF0000:"System memory usage (%)"
    $rrdgraph $monthly $GRAPHPATH/sysmem-monthly.png DEF:sysmem=$DBPATH/sysmem.rrd:sysmem:AVERAGE \
              LINE1:sysmem#FF0000:"System memory usage (%)"

    #Generate graphs: system load
    $rrdgraph $hourly  $GRAPHPATH/sysload-hourly.png  DEF:sysload=$DBPATH/sysload.rrd:sysload:LAST \
              LINE1:sysload#FF0000:"System load"
    $rrdgraph $daily   $GRAPHPATH/sysload-daily.png   DEF:sysload=$DBPATH/sysload.rrd:sysload:AVERAGE \
              LINE1:sysload#FF0000:"System load"
    $rrdgraph $weekly  $GRAPHPATH/sysload-weekly.png  DEF:sysload=$DBPATH/sysload.rrd:sysload:AVERAGE \
              LINE1:sysload#FF0000:"System load"
    $rrdgraph $monthly $GRAPHPATH/sysload-monthly.png DEF:sysload=$DBPATH/sysload.rrd:sysload:AVERAGE \
              LINE1:sysload#FF0000:"System load"
    
    
    
    #Generate graphs: core temperatures
    local labels=$(getListOfCPUs)
    if [ "$labels" != "" ] ; then
        #Hourly
        local nextColour=0 #Reset the color sequence
	       local lines=""
	       for label in $labels
	       do
	           local colour=$(getRGBCode $nextColour)
            nextColour=$((nextColour+1))
            local line="DEF:$label=$DBPATH/coretemperatures.rrd:$label:LAST  LINE1:$label#$colour:'$label(C)'"
	           lines="$lines $line"
	       done
	       $rrdgraph $hourly  $GRAPHPATH/coretemps-hourly.png  $lines
        
        #Daily/Weekly/Monthly
        local nextColour=0 #Reset the color sequence
        local lines=""
	       for label in $labels
	       do
	           local colour=$(getRGBCode $nextColour)
            nextColour=$((nextColour+1))
            local line="DEF:$label=$DBPATH/coretemperatures.rrd:$label:AVERAGE  LINE1:$label#$colour:'$label(C)'"
	           lines="$lines $line"
	       done
	       $rrdgraph $daily   $GRAPHPATH/coretemps-daily.png   $lines
	       $rrdgraph $weekly  $GRAPHPATH/coretemps-weekly.png  $lines
	       $rrdgraph $monthly $GRAPHPATH/coretemps-monthly.png $lines
    fi
    
    
    
    #Generate graphs: HDD temperatures
    local labels=$(listSMARTHDDs)
    if [ "$labels" != "" ] ; then
        #Hourly
        local nextColour=0 #Reset the color sequence
	       local lines=""
	       for label in $labels
	       do
            label=$(basename $label)
	           local colour=$(getRGBCode $nextColour)
            nextColour=$((nextColour+1))
            local line="DEF:$label=$DBPATH/hddtemperatures.rrd:$label:LAST  LINE1:$label#$colour:'$label(C)'"
	           lines="$lines $line"
	       done
	       $rrdgraph $hourly  $GRAPHPATH/hddtemps-hourly.png  $lines
        
        #Daily/Weekly/Monthly
        local nextColour=0 #Reset the color sequence
        local lines=""
	       for label in $labels
	       do
            label=$(basename $label)
	           local colour=$(getRGBCode $nextColour)
            nextColour=$((nextColour+1))
            local line="DEF:$label=$DBPATH/hddtemperatures.rrd:$label:AVERAGE  LINE1:$label#$colour:'$label(C)'"
	           lines="$lines $line"
	       done
	       $rrdgraph $daily   $GRAPHPATH/hddtemps-daily.png   $lines
	       $rrdgraph $weekly  $GRAPHPATH/hddtemps-weekly.png  $lines
	       $rrdgraph $monthly $GRAPHPATH/hddtemps-monthly.png $lines
    fi
    
    
    
    #Generate graphs: IO rate for each HDD, read and write
    local labels=$(listHDDs)
    if [ "$labels" != "" ] ; then
        #Hourly
        local nextColour=0 #Reset the color sequence
	       local linesRead=""
        local linesWrite=""
	       for label in $labels
	       do
            label=$(basename $label)
	           local colour=$(getRGBCode $nextColour)
            nextColour=$((nextColour+1))
            local labelRead=$label"-read"
            local labelWrite=$label"-write"
            local lineRead="DEF:$labelRead=$DBPATH/hddio.rrd:$labelRead:LAST  
                            LINE1:$labelRead#$colour:'$label(blocks/s-read)'"
	           local lineWrite="DEF:$labelWrite=$DBPATH/hddio.rrd:$labelWrite:LAST  
                            LINE1:$labelWrite#$colour:'$label(blocks/s-written)'"
	           linesRead="$linesRead $lineRead"
	           linesWrite="$linesWrite $lineWrite"
	       done
        $rrdgraph $hourly  $GRAPHPATH/hddior-hourly.png  $linesRead
	       $rrdgraph $hourly  $GRAPHPATH/hddiow-hourly.png  $linesWrite
        
        #Daily/Weekly/Monthly
        local nextColour=0 #Reset the color sequence
	       local linesRead=""
        local linesWrite=""
	       for label in $labels
	       do
            label=$(basename $label)
	           local colour=$(getRGBCode $nextColour)
            nextColour=$((nextColour+1))
            local labelRead=$label"-read"
            local labelWrite=$label"-write"
            local lineRead="DEF:$labelRead=$DBPATH/hddio.rrd:$labelRead:AVERAGE  
                            LINE1:$labelRead#$colour:'$label(blocks/s-read)'"
	           local lineWrite="DEF:$labelWrite=$DBPATH/hddio.rrd:$labelWrite:AVERAGE  
                            LINE1:$labelWrite#$colour:'$label(blocks/s-written)'"
	           linesRead="$linesRead $lineRead"
	           linesWrite="$linesWrite $lineWrite"
	       done
        $rrdgraph $daily   $GRAPHPATH/hddior-daily.png   $linesRead
	       $rrdgraph $weekly  $GRAPHPATH/hddior-weekly.png  $linesRead
	       $rrdgraph $monthly $GRAPHPATH/hddior-monthly.png $linesRead
	       $rrdgraph $daily   $GRAPHPATH/hddiow-daily.png   $linesWrite
	       $rrdgraph $weekly  $GRAPHPATH/hddiow-weekly.png  $linesWrite
	       $rrdgraph $monthly $GRAPHPATH/hddiow-monthly.png $linesWrite
    fi
	   
    
    
    #Generate graphs: Accumulated ethernet IO for each interface, tx and rx
    local labels=$(getEthInterfaces)
    if [ "$labels" != "" ] ; then
        #Hourly
        local nextColour=0 #Reset the color sequence
	       local linesRead=""
        local linesWrite=""
	       for label in $labels
	       do
	           local colour=$(getRGBCode $nextColour)
            nextColour=$((nextColour+1))
            local labelRead=$label"-rx"
            local labelWrite=$label"-tx"
            local lineRead="DEF:$labelRead=$DBPATH/networkio.rrd:$labelRead:LAST  
                            LINE1:$labelRead#$colour:'$label(Bytes-Rx)'"
	           local lineWrite="DEF:$labelWrite=$DBPATH/networkio.rrd:$labelWrite:LAST  
                            LINE1:$labelWrite#$colour:'$label(Bytes-Tx)'"
	           linesRead="$linesRead $lineRead"
	           linesWrite="$linesWrite $lineWrite"
	       done
        $rrdgraph $hourly  $GRAPHPATH/networkiorx-hourly.png  $linesRead
	       $rrdgraph $hourly  $GRAPHPATH/networkiotx-hourly.png  $linesWrite
        
        #Daily/Weekly/Monthly
        local nextColour=0 #Reset the color sequence
	       local linesRead=""
        local linesWrite=""
	       for label in $labels
	       do
	           local colour=$(getRGBCode $nextColour)
            nextColour=$((nextColour+1))
            local labelRead=$label"-rx"
            local labelWrite=$label"-tx"
            local lineRead="DEF:$labelRead=$DBPATH/networkio.rrd:$labelRead:AVERAGE  
                            LINE1:$labelRead#$colour:'$label(Bytes-Rx)'"
	           local lineWrite="DEF:$labelWrite=$DBPATH/networkio.rrd:$labelWrite:AVERAGE  
                            LINE1:$labelWrite#$colour:'$label(Bytes-Tx)'"
	           linesRead="$linesRead $lineRead"
	           linesWrite="$linesWrite $lineWrite"
	       done
        $rrdgraph $daily   $GRAPHPATH/networkiorx-daily.png   $linesRead
	       $rrdgraph $weekly  $GRAPHPATH/networkiorx-weekly.png  $linesRead
	       $rrdgraph $monthly $GRAPHPATH/networkiorx-monthly.png $linesRead
	       $rrdgraph $daily   $GRAPHPATH/networkiotx-daily.png   $linesWrite
	       $rrdgraph $weekly  $GRAPHPATH/networkiotx-weekly.png  $linesWrite
	       $rrdgraph $monthly $GRAPHPATH/networkiotx-monthly.png $linesWrite
    fi
    
    
    
    #Apache memory and CPU usage
    $rrdgraph $hourly  $GRAPHPATH/apacheresusage-hourly.png  \
	             DEF:apachecpu=$DBPATH/apacheload.rrd:apachecpu:LAST \
              LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
              DEF:apachemem=$DBPATH/apacheload.rrd:apachemem:LAST \
              LINE1:apachemem#00FF00:"Memory used by Apache (%)"

    $rrdgraph $daily   $GRAPHPATH/apacheresusage-daily.png   \
	             DEF:apachecpu=$DBPATH/apacheload.rrd:apachecpu:AVERAGE \
              LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
              DEF:apachemem=$DBPATH/apacheload.rrd:apachemem:AVERAGE \
              LINE1:apachemem#00FF00:"Memory used by Apache (%)"
    
    $rrdgraph $weekly  $GRAPHPATH/apacheresusage-weekly.png  \
	             DEF:apachecpu=$DBPATH/apacheload.rrd:apachecpu:AVERAGE \
              LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
              DEF:apachemem=$DBPATH/apacheload.rrd:apachemem:AVERAGE \
              LINE1:apachemem#00FF00:"Memory used by Apache (%)"
    
    $rrdgraph $monthly $GRAPHPATH/apacheresusage-monthly.png \
	             DEF:apachecpu=$DBPATH/apacheload.rrd:apachecpu:AVERAGE \
              LINE1:apachecpu#FF0000:"CPU used by Apache (%)" \
              DEF:apachemem=$DBPATH/apacheload.rrd:apachemem:AVERAGE \
              LINE1:apachemem#00FF00:"Memory used by Apache (%)"
    
    
    
    #Disk partition usage
    local labels=""
    for disk in $(listHDDs) ; do
	       for par in  $(getPartitionsForDrive  $disk) ; do 
	           local usageperc=$(partitionUsagePercent $par)
	           if [ "$usageperc" != "" ] ; then
		              label=$(basename $par)
		              labels="$labels $label"
	           fi
	       done
    done
    labels="$labels EncryptedFS"
    labels="$labels RamFS"
    
    
    if [ "$labels" != "" ] ; then
        #Hourly
        local nextColour=0 #Reset the color sequence
	       local lines=""
	       for label in $labels
	       do
	           local colour=$(getRGBCode $nextColour)
            nextColour=$((nextColour+1))
            local line="DEF:$label=$DBPATH/diskusage.rrd:$label:LAST  LINE1:$label#$colour:'$label(%-in-use)'"
	           lines="$lines $line"
	       done
	       $rrdgraph $hourly  $GRAPHPATH/diskusage-hourly.png  $lines
        
        #Daily/Weekly/Monthly
        local nextColour=0 #Reset the color sequence
        local lines=""
	       for label in $labels
	       do
	           local colour=$(getRGBCode $nextColour)
            nextColour=$((nextColour+1))
            local line="DEF:$label=$DBPATH/diskusage.rrd:$label:AVERAGE  LINE1:$label#$colour:'$label(%-in-use)'"
	           lines="$lines $line"
	       done
	       $rrdgraph $daily   $GRAPHPATH/diskusage-daily.png   $lines
	       $rrdgraph $weekly  $GRAPHPATH/diskusage-weekly.png  $lines
	       $rrdgraph $monthly $GRAPHPATH/diskusage-monthly.png $lines
    fi
    
    
    return 0
}









#Build web pages showing the stats
generateStatsPages () {
    
    
    #Grab all the graph filenames
    local graphFiles=$(ls $GRAPHPATH/*.png)
    
    #Tab pages to be generated
    local pages="hourly daily weekly monthly"
    
    
    for page in $pages ; do

        #Name of this tab
        local filepath="$GRAPHPATH/$page.html"

        #Images that will go in this tab
        local pageGraphs=$(echo $graphFiles | grep -oEe "[-._0-9a-zA-Z]+-$page.png")    
        
        
        #Page header
        echo "<html>
                <head>
                  <meta http-equiv=\"REFRESH\" content=\"60\">
                  <title>Voting Server Statistics</title>
                </head>
                <body>" > $filepath
        
        echo "    <h1>Server Statistics</h1>
                  <h3>$(hostname -f)</h3>
                  <b>Period</b>: $page <br/>
                  <b>Current time</b>: <script>var date = new Date(); document.write(date.toISOString());</script> <br/>
                  <br/>
                  <br/>" >> $filepath

        #Show tab links (except for current one)
        for tab in $pages ; do
	           [ $tab != $page ] && echo ' <a href="'$tab'.html">'$tab'</a>  ' >> $filepath
	           [ $tab == $page ] && echo "$tab  " >> $filepath
        done
        echo '<br/>
              <br/>' >> $filepath
        
        #Show all the graphs for the tab
        for graph in $pageGraphs
        do
	           if [ -s "$GRAPHPATH/$graph" ] ; then
	               echo '<br/>
                      <br/>
                      <img src="'$graph'"/>' >> $filepath
	           fi
	       done

        #Footer
        echo "  </body>
              </html>" >> $filepath
    done
    
    
    #Copy the hourly tab as the entry point (can't link due to
    #NofollowSymLink policy)
    cp -f $GRAPHPATH/hourly.html $GRAPHPATH/index.html  >>$STATLOG 2>>$STATLOG
    chmod 740 $GRAPHPATH/index.html                     >>$STATLOG 2>>$STATLOG
    chown root:www-data $GRAPHPATH/index.html           >>$STATLOG 2>>$STATLOG
    
    return 0
}







updateGraphs () {
    
    #Delete former graphs, if any
	   rm -vf "$GRAPHPATH"/*  >>$STATLOG 2>>$STATLOG
    
    #Create directory, in case it doesn't exist
    mkdir -p  "$GRAPHPATH"  >>$STATLOG 2>>$STATLOG
    chmod 750 "$GRAPHPATH"  >>$STATLOG 2>>$STATLOG
    chown root:www-data "$GRAPHPATH"  >>$STATLOG 2>>$STATLOG

    
    #Build the udated graphs
    generateGraphs   >>$STATLOG 2>>$STATLOG
    
    
    #Build the pages
    generateStatsPages

    #Set permissions and ownership to the generated graphs and pages
    chown root:www-data "$GRAPHPATH"/*
    chmod 740 "$GRAPHPATH"/*
    
    return 0
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
    
    gatherTimeDifferentialMetrics   2>>$STATLOG
    
    
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






#Setup statistics databases and web application
if [ "$OPERATION" == "start" ]
then
    
    #Delete former databases, if any contents
	   rm -vf $DBPATH/*     >>$STATLOG 2>>$STATLOG
    #Create directory, in case it doesn't exist 
    mkdir -vp "$DBPATH"   >>$STATLOG 2>>$STATLOG
    chmod 750 "$DBPATH"   >>$STATLOG 2>>$STATLOG
    
    #Create databases
    createStatsDatabases
    
    exit 0
fi





#Feed the stats databases and regenerate the graphs
if [ "$OPERATION" == "update" ]
then
    gatherTimeDifferentialMetrics   2>>$STATLOG
    
    updateLog
    
    updateGraphs
    exit 0
fi






#Feed the stats databases
if [ "$OPERATION" == "updateLog" ]
then
    gatherTimeDifferentialMetrics   2>>$STATLOG
    
    updateLog
    exit 0
fi






#Regenerate the statistics graphs
if [ "$OPERATION" == "updateGraphs" ]
then
    
    updateGraphs
    exit 0

fi




# TODO lo que se implemente aquí, que valga para ser llamado tal cual en el setup, así no hace falta reinstalar los sistemas ya desplegados para activar las stats

## TODO make sure there is no output or expected error output
