#!/usr/bin/python

#Simple HTTPS server. Will serve only same working directory files

import BaseHTTPServer, SimpleHTTPServer
import ssl
import sys


if len(sys.argv) < 5 :
    print "Usage: "+sys.argv[0]+" bind_addr port sslKey_path sslCert_path"
    exit(1)

addr = sys.argv[1]
port = int(sys.argv[2])
key  = sys.argv[3]
cert = sys.argv[4]

print "Listening on "+addr+":"+str(port)
print "Private key: "+key
print "Certificate: "+cert





#Launch the HTTP basic server
httpd = BaseHTTPServer.HTTPServer((addr, port),
                                  SimpleHTTPServer.SimpleHTTPRequestHandler)

#Wrap it with a SSL socket 
httpd.socket = ssl.wrap_socket (httpd.socket,
                                keyfile=key,
                                certfile=cert,
                                server_side=True)
#Start listening
httpd.serve_forever()
