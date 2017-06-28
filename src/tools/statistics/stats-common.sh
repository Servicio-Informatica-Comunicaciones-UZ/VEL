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

#On the color code sequence, the current status
LASTRGBCODE=-1




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





#Will print a different color code following a determined sequence,
# will keepthe sequence on a global variable. To be used for
# multi-line graphing
#1 -> 'reset': restar sequence
#Expects the following globals:
# LASTRGBCODE
getNextRGBCode () {
    
    #Reset the color sequence, don't print any
    if [ "$1" == "reset" ] ; then
        LASTRGBCODE=-1 #Values: (0 - 15)
        return 0
    fi
    
    #The sequence of colors (16)
    local RGBCodes=(FF0000 00FF00 0000FF FF7700 00C000 330000 330066 666600 \
                           FF99CC 000000 FFCC00 99CCFF 339900 666666 9966FF FF0077)
    local len=${#RGBCodes[@]}
    
    
    #Increment the sequence
	   LASTRGBCODE=$((LASTRGBCODE+1))
    
    #Wrap it around if overflowed (unlikely, but well)
    if [ $LASTRGBCODE -ge  $len  ] ; then
	       LASTRGBCODE=0
    fi
    
    #Print the next color code
	   echo -n ${RGBCodes[$LASTRGBCODE]}
	   return 0
}
