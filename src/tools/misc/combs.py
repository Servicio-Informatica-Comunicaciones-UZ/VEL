#!/usr/bin/python

#Given a Set Size (N) and a combination size (M) prints all different combinations of M items inside N space, each separated by -, and each combination separated by space+\n

#Use results as set element indexes to get all combinations of a given set

import sys

def enumerate (st,K, ni):
    if K == 0:
        line=""
        for it in st:
            line=line+str(it)+"-"
        line=line[:-1]
        print line+" "
        
    else:
        for i in xrange(ni,N):
            st.append(i)
            enumerate(st, K-1, i+1)
            st.pop()




#print "command line: "+str(sys.argv)



if len(sys.argv) != 3:
    sys.stderr.write("Usage: combs.py CombSize SetSize\n")
    exit(1)

try:
    M=int(sys.argv[1])
    N=int(sys.argv[2])
except:
    sys.stderr.write("Parameters must be integers\n")
    exit(1)
    
if N<M :
    sys.stderr.write("Combination size must be less than set size\n")
    exit(1)


enumerate([],M,0)


exit(0)
