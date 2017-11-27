#!/usr/bin/python
# -*- coding: iso-8859-1 -*-





from __future__ import print_function
import re
import sys



a=sys.stdin.read()
#a='\n$asdasdasda=\'\';\nasdfasdfas\n        //!\n      $asdasd=\'\';$asdasd=\'\';\n$asdasd=\'\';\nfffffffffff\n$asdasdasda=\'\';\nmdgdfgdfgdfdgfdf\n'


#print "---------\n"+a+"-----------\n"

p  = re.compile('(//!.*?)\n(.*?)\$(.*?)=.*?\n', re.S|re.M)

print(re.sub(p, "\g<1>\n\g<2>$\g<3>='###***\g<3>***###';\n", a), end='')


'''


#La unica forma de imprimir el ! sin que imprima la barra de escape es con una cadena single-quoted
#Pasarselo con un cat si es posible
echo -e "\n\$asdasdasda='';\nasdfasdfas\n        //"'!'"\n      \$asdasd='';\$asdasd='';\n\$asdasd='';\nfffffffffff\n\$asdasdasda='';\nmdgdfgdfgdfdgfdf\n"| python ~/Desktop/markVariables.py



'''
