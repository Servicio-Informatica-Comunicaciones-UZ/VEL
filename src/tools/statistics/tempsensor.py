#!/usr/bin/python


import os
import sys
import glob
import re




basedir='/sys/class/hwmon/'


def getDevices ():
    devices = os.listdir(basedir)
    return devices

#Get input for every fan sensor
def getFans(dev):
    fans = glob.glob(basedir+dev+'/device/fan*_input')
    ret=[]
    for fan in fans:
        label=re.compile("^fan[0-9]+").findall(os.path.basename(fan))[0]
        value=open(fan,"rb").read().rstrip()
        #print label+": "+value+" rpm"
        ret.append(label+":\t"+value+" rpm")
        
    return ret
    

#Get label(if not null) and input for every sensor
def getTemps(dev, submode=''):
    temps = glob.glob(basedir+dev+'/device/temp*_input')
    ret=[]
    for temp in temps:
        
        number=re.compile("[0-9]+").findall(os.path.basename(temp))[0]
        
        #Si existe label, la leemos
        labelfile=basedir+dev+'/device/temp'+number+'_label'
        if os.path.isfile(labelfile):
            #print "LABEL: "+open(labelfile,"rb").read().rstrip()
            label=open(labelfile,"rb").read().rstrip()
        else:
            label=re.compile("^temp[0-9]+").findall(os.path.basename(temp))[0]
            
        value=int(open(temp,"rb").read().rstrip())/1000
        #print label+": "+value+" C"
        if submode == 'list':
            devname=open(basedir+dev+'/device/name',"rb").read().rstrip()
            ret.append(devname+"-"+label)
        elif submode == 'data':
            ret.append(str(value)) 
        else:
            ret.append(label+":\t"+str(value)+" C")
            
    return ret



def getACPITemp (submode=''):
    
    tempfile="/proc/acpi/thermal_zone/THRM/temperature"
        
    
    ret = ''
    
    if os.path.isfile(tempfile):
        strval=open(tempfile,"rb").read().strip()
        temp=re.compile("[0-9]+\s*C$").findall(strval)[0]

        if submode == 'list':
            ret = 'ACPI-Thermal-zone'
        elif submode == 'data':
            ret = str(temp) 
        else:
            ret = 'ACPI Thermal zone: '+temp
            
    return ret




    





# 1 -> fan o temp. El valor de retorno es 1 si no existen valores o 0 si existe al menos un valor

# [solo temp]
# 2 -> (nada): devuelve los datos estructurados paras er imprimidos
#      'list': devuelve listado de cadenas "devName-tempSensor", para indicar todas las fuentes de datos posibles
#      'data': devuelve los datos de temperatura para todos los sensores, en el orden de la lista anterior




if len(sys.argv) <=1:
    mode='temp'
else:
    mode=sys.argv[1]


submode=''
if len(sys.argv) >= 3:
    submode=sys.argv[2]



devs=getDevices()

devnameDict = {}



if not devs:
    exit(1)

#print devs 


output=[]


if mode == 'temp':
    acpi=getACPITemp(submode)
    if acpi != "":
        output.append(acpi)
        
        

for dev in devs:

    #En hwmon tb se lista el ACPI, y peta pq no tiene esta estructura. Los evitamos
    try:
        #Devname
        devname=open(basedir+dev+'/device/name',"rb").read().rstrip()
    except:
        continue
    #print "Before: "+devname

    if devname in devnameDict:
        devnameDict[devname]+=1
        devname=devname+" "+str(devnameDict[devname])
    else:
        devnameDict[devname]=0
        
    
    #Sensors for this dev

    #Buscar fans o temps

    if mode == 'fan':
        sens=getFans(dev)
    elif mode == 'temp':
        sens=getTemps(dev, submode)
    else:
        print "Unknown mode!"
        exit(1)


        
    if submode != '' :
        for s in sens:
            output.append(s.replace(' ', '_'))
        
    else:
        if len(sens)>0:
            output.append("Device: "+devname)
            
            for s in sens:
                output.append("  "+s)
                

if len(output)>0:
    for line in output:
        print line
    exit(0)

exit(1)



