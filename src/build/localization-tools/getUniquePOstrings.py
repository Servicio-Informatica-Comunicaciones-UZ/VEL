#!/usr/bin/python
# -*- coding: iso-8859-1 -*-


#Gets a .po file (of l10n gettex strings) and returns it without duplicates

#getUniquePOstrings.py <POfile> [<outFile>]



import re
import sys


if len(sys.argv)<2 or len(sys.argv)>3:
    sys.stderr.write("Usage: getUniquePOstrings.py <POfile> [<outFile>]\n")
    exit(1)


infilename=sys.argv[1]
outfilename=""
try:
    outfilename=sys.argv[2]
except:
    pass

try:
    ifh=open(infilename,"r")
except:
    sys.stderr.write("File: "+infilename+" not found.\n")
    exit(2)


try:
    inlines=ifh.readlines()
except:
    sys.stderr.write("File: "+infilename+". Read error.\n")
    exit(3)
    
ifh.close()

if len(inlines)<=0:
    sys.stderr.write("File: "+infilename+". Empty file.\n")
    exit(4)



#print inlines


datablocks=[]
block=[]

count=0
for line in inlines:
    if count==0:
        block=[line]
    elif count==1:
        block.append(line)
    else: # count ==2
        block.append(line)
        datablocks.append(block)
    
    count=(count+1)%3
    
    
#print datablocks



if outfilename=="":
    ofh=sys.stdout
else:
    try:
        ofh=open(outfilename,"w")
    except:
        sys.stderr.write("File: "+infilename+" not found.\n")
        exit(2)
        
        
        

linesdict={}

for block in datablocks:

    try: #Si ya existe la línea en el dict, la ignora
        linesdict[block[1]]
    except: #si no existe,la escribe en el resultado y la marca en el dict
        for line in block:
            ofh.write(line);
        linesdict[block[1]]=True

    


        

if outfilename!="":
    ofh.close()

#New translation:
# ISO to UTF. ScriptFile.sh
# bash --dump-po-strings ScriptFile.sh > DestFile.pot
# getUniquePOstrings.py DestFile.pot TranslationsFile.po
# Copy to its language directory and translate
# msgfmt -o CompiledTranslFile.mo TranslationsFile.po 



#To update:
# ISO to UTF. ScriptFile.sh
# bash --dump-po-strings ScriptFile.sh > NewTranslationsFile.pot
# getUniquePOstrings.py DestFile.pot TranslationsFile.pot
# msgmerge --update  --previous --no-wrap  CurrentTranslationsFile.po NewTranslationsFile.pot
# Copy to its language directory and translate new strings
# msgfmt -o CompiledTranslFile.mo TranslationsFile.po 




# ISO to UTF:
#iconv --from-code=ISO-8859-1 --to-code=UTF-8 inFile > aux
#mv -f aux  outFile

#Poner esta cabecera, para que coja bien el charset
'''
# Trad File
#
#, fuzzy
msgid ""
msgstr ""
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"
'''
