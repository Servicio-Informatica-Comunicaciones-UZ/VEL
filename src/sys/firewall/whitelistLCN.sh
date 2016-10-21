#!/bin/bash

. /usr/local/bin/common.sh


PATH=$PATH:/sbin:/usr/sbin

x=$(wget -q 2>/dev/null -O - https://esurvey.nisu.org/nodes.xml |
           sed -ne 's%\s*<url>http://\([^/:]*\)[/:].*%\1%p')

#To avoid removing the list of nodes from the whitelist if wget fails
if [ "$x" ]; then
    #Add the list to the current whitelist
    echo "$x" >>  /etc/whitelist
    #Remove duplicates
    y=$(cat /etc/whitelist | sort | uniq)
    echo "$y" >  /etc/whitelist
fi
