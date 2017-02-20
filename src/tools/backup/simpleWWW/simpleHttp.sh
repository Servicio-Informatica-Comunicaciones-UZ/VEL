#!/bin/bash


#Common functions for privileged and unprivileged scripts.
. /usr/local/bin/common.sh

#Common functions for privileged scripts
. /usr/local/bin/privileged-common.sh



basePath=/usr/local/share/simpleWeb

#Get own public IP address (where services will be bound)
IPADDR=$(getOwnIP)

serverCrt="/etc/ssl/certs/server.crt"
serverKey="/etc/ssl/private/server.key"



case "$1" in
	   "start" )
        
        pushd "$basePath/html" >>$LOGFILE 2>>$LOGFILE
        
        if [ ! -s "./index.html" ] ; then
            log "maintenance web page not found. Not launching webservers."
            exit 1
        fi

        #Plain http server
        python -m SimpleHTTPServer 80 >>$LOGFILE 2>/dev/null &
        httpPid=$!
        echo "HTTP service PID: "$httpPid >>$LOGFILE 2>>$LOGFILE
        
        #Store PID
        echo -n "$httpPid" > $basePath/http.pid
        

        #Https server
        $basePath/simpleHttps.py "$IPADDR"  443  "$serverKey"  "$serverCrt" >>$LOGFILE 2>/dev/null &
        httpsPid=$!
        echo "HTTPS service PID: "$httpsPid >>$LOGFILE 2>>$LOGFILE

        #Store PID
        echo -n "$httpsPid" > $basePath/https.pid
        
        
        #Detach the services from this terminal
        disown -ar
        
        popd >>$LOGFILE 2>>$LOGFILE
        ;; 
    
    
    "stop" )
        kill $(cat $basePath/http.pid)  2>>$LOGFILE
        kill $(cat $basePath/https.pid) 2>>$LOGFILE
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
