#!/usr/bin/python
# -*- coding: iso-8859-15; mode: Python; indent-tabs-mode: nil; tab-width: 1; -*-

import re
import sys
import os


usage="Usage: "+sys.argv[0]+" <variableFile> <variable> <value>\n"

if len(sys.argv) != 4:
    sys.stderr.write(usage)
    exit(1)
filename = sys.argv[1]
variable = sys.argv[2].strip()
value    = sys.argv[3].strip()




#If file doesn't exist, create
if not os.path.exists(filename):
    open(filename, 'w').close()

#Read the file 
with open(filename, 'r') as f:
    content = f.readlines()

#Search for the variable in all the lines
search = re.compile(r"^"+variable+"=")
found = False
for lnum, line in enumerate(content):
    #If found, overwrite value
    if search.match(line):
        found = True
        content[lnum] = variable+'="'+value+'"\n'

#If not found, append a new line (no escaping needed here, it is
#already done or prohibited)
if not found:
    content.append(variable+'="'+value+'"\n')

#Write the file again
with open(filename, 'w') as f:
    for line in content:
        f.write(line)
