#!/usr/bin/python

#Simple HTTPS server. Will serve only same page

import BaseHTTPServer, SimpleHTTPServer
import ssl
import sys

usage="Usage: "+sys.argv[0]+" [plain|ssl] bind_addr port document_path (sslKey_path) (sslCert_path)"



if len(sys.argv) < 2 :
    print "Too few arguments"
    print usage
    exit(1)

sslMode = sys.argv[1]


if sslMode == 'ssl':
    print "SSL mode, at least 6 arguments required."
    if len(sys.argv) < 7 :
        print usage
        exit(1)
else:
    print "Plain mode, at least 4 arguments required."
    if len(sys.argv) < 5 :
        print usage
        exit(1)
        
addr    = sys.argv[2] #If empty string, will serve on 0.0.0.0
port    = int(sys.argv[3])
docPath = sys.argv[4]

if sslMode =='ssl':
    key     = sys.argv[5]
    cert    = sys.argv[6]


print "Listening on "+addr+":"+str(port)
if sslMode == 'ssl':
    print "Private key: "+key
    print "Certificate: "+cert


class SplashPageHandler(BaseHTTPServer.BaseHTTPRequestHandler):
    
    def buildResponse(self):
        self.send_response(200)
        self.send_header('Content-type','text/html')
        self.end_headers()
        # Send the same html message always (read it on every request
        # just in case it is written)
        with open(docPath, 'r') as indexDoc:
            page=indexDoc.read()
        self.wfile.write(page)
        return
    
    #Handler for the GET requests
    def do_GET(self):
        return self.buildResponse();


    def do_POST(self):
        return self.buildResponse();
    


    
#Launch the HTTP basic server
httpd = BaseHTTPServer.HTTPServer((addr, port),
                                  #SimpleHTTPServer.SimpleHTTPRequestHandler)
                                  SplashPageHandler)
if sslMode == 'ssl':
    #Wrap it with a SSL socket 
    httpd.socket = ssl.wrap_socket (httpd.socket,
                                    keyfile=key,
                                    certfile=cert,
                                    server_side=True)
#Start listening
httpd.serve_forever()
