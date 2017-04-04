#!/bin/bash


#Common functions for privileged and unprivileged scripts.
. /usr/local/bin/common.sh

#Common functions for privileged scripts
. /usr/local/bin/privileged-common.sh



basePath=/usr/local/share/simpleWeb

#Get own public IP address (where services will be bound)
#IPADDR=$(getOwnIP)
IPADDR="" #This way it will listen on all IPs

serverCrt="/etc/ssl/certs/server.crt"
serverKey="/etc/ssl/private/server.key"



case "$1" in
	   "start" )
        
        if [ ! -s "$basePath/html/index.html" ] ; then
            log "maintenance web page not found. Not launching webservers."
            exit 1
        fi
        
        #Plain http server
        $basePath/simpleHttps.py plain "$IPADDR"  80  "$basePath/html/index.html"  >>$LOGFILE 2>>$LOGFILE &
        httpPid=$!
        echo "HTTP service PID: "$httpPid >>$LOGFILE 2>>$LOGFILE
        
        #Store PID
        echo -n "$httpPid" > $basePath/http.pid
        
        
        #Https server
        $basePath/simpleHttps.py ssl "$IPADDR"  443  "$basePath/html/index.html"  "$serverKey"  "$serverCrt" >>$LOGFILE 2>>$LOGFILE &
        httpsPid=$!
        echo "HTTPS service PID: "$httpsPid >>$LOGFILE 2>>$LOGFILE
        
        #Store PID
        echo -n "$httpsPid" > $basePath/https.pid
        
        
        #Detach the services from this terminal # TODO is this needed?
        disown -ar
        ;;
    
    
    "stop" )
        kill -9 $(cat $basePath/http.pid)  2>>$LOGFILE
        kill -9 $(cat $basePath/https.pid) 2>>$LOGFILE

        #Just to make sure
        pid1=$(netstat -ntaep | grep :80 | sed -re "s/\s+/ /g" | cut -d " " -f 9 | sed -re "s|^([0-9]+)/python$|\1|g" 2>>$LOGFILE)
        pid2=$(netstat -ntaep | grep :443 | sed -re "s/\s+/ /g" | cut -d " " -f 9 | sed -re "s|^([0-9]+)/python$|\1|g" 2>>$LOGFILE)
        kill -9 $pid1  2>>$LOGFILE
        kill -9 $pid2  2>>$LOGFILE
        
        rm $basePath/http.pid  2>>$LOGFILE
        rm $basePath/https.pid  2>>$LOGFILE
        ;;
    
    * )
        echo "Usage $0 start|stop"
        exit 1
        ;;
    
esac


#This one fails on a url without the index.html
#openssl s_server -accept 8443 -cert server.cert -key server.key -WWW

#This one fails to guess *.php from  *.html
#python -m SimpleHTTPServer 80 >>$LOGFILE 2>>$LOGFILE &
