#!/bin/bash


#Auxiliary functions



###############
#  Constants  #
###############

#Make sure locales don't affect indicator collection
LC_ALL=C


#Destination of all the output. Different from the wizard log as this
#generates a huge amount of output. Recommended values:
# In production: /dev/null
# To receive e-mails on updates: /dev/stdout
# To log on a file: /tmp/statsLog
STATLOG=/dev/null
#<DEBUG>
STATLOG=/tmp/statsLog
#</DEBUG>


######################
#  Global variables  #
######################





#############
#  Methods  #
#############



#Prints current date and time in ISO format
currentDateTime () {
    echo -n $(date +%c)
    return 0
}



#Prints how many CPU cores the system has
getNumberOfCPUs () {
    echo -n $(ls /sys/devices/system/cpu/cpu[0-9]* -d | wc -l)
}




#Lists the cores existing in the system.
getListOfCPUs () {
    #Translate space on the name
    echo -n $(sensors | grep -oEe "^Core [0-9]+" | tr " " "_")
}



#Lists HDD devs that have SMART protocol support
listSMARTHDDs () {
    smartctl --scan | cut -d " " -f 1
}


    
#Will print a different color code following a determined sequence
#based on the input integer. To be used for multi-line graphing
#1 -> color position
getRGBCode () {
    
    local position="$1"
    [ "$position" ==  ""  ] && position=0
    
    #The sequence of colors (16)
    local RGBCodes=(FF0000 00FF00 0000FF FF7700 00C000 330000 330066 666600 \
                           FF99CC 000000 FFCC00 99CCFF 339900 666666 9966FF FF0077)
    local len=${#RGBCodes[@]}
    
    #Wrap it around if overflowed (unlikely, but well)
    if [ $position -ge  $len  -o  $position -lt 0 ] ; then
	       position=$((position%len))
    fi
    
    #Print the requested color code
	   echo -n ${RGBCodes[$position]}
    return 0
}
