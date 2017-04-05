#!/usr/bin/python
# -*- coding: iso-8859-1 -*-

# separateCerts.py inFilePath
#
# Reads a file with a number of PEM certificates, which is split into
# individual certificates and may files are written, with numbered
# correlative names prefixed with the original filename:
# inputFilename[0-9]+ .



import re
import sys





if len(sys.argv)<2 or len(sys.argv)>2:
    sys.stderr.write("Usage: separateCerts.py <inFilePath>\n")
    exit(1)


filename=sys.argv[1]

try:
    fh=open(filename,"r")
except:
    sys.stderr.write("File: "+filename+" not found.\n")
    exit(2)


try:
    crtstr=fh.read()
except:
    sys.stderr.write("File: "+filename+". Read error.\n")
    exit(3)
    
fh.close()

if len(crtstr)<=0:
    sys.stderr.write("File: "+filename+". Empty file.\n")
    exit(4)



crtarr=re.findall("-+.*?BEGIN.*?CERTIFICATE.*?-+.*?-+.*?END.*?CERTIFICATE.*?-+.*?",crtstr,re.S)

if len(crtarr)<=0:
    sys.stderr.write("File: "+filename+". No PEM certificates in file.\n")
    exit(5)

#if len(crtarr)<2:
#    sys.stderr.write("File: "+filename+". 2 certs expected at least.\n")
#    exit(6)


count=0
for cert in crtarr:
    fh=open(filename+"."+str(count),"w")
    fh.write(cert+"\n\n")
    fh.close()
    
    count+=1
    
    


exit(0)
