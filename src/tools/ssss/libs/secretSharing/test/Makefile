CXX = g++

SSLIBS = ../secretSharing.o ../secretSharer.o


all: testAll testAllSameObject testSS

testAll: testAll.cpp $(SSLIBS)
	$(CXX) -c testAll.cpp  
	$(CXX) -o test testAll.o $(SSLIBS) -lcrypto
	chmod u+x test

testAllSameObject: testAllSame.cpp $(SSLIBS)
	$(CXX) -c testAllSame.cpp  
	$(CXX) -o test2 testAllSame.o $(SSLIBS) -lcrypto
	chmod u+x test2

testSS:  testSecretSharing.cpp ../secretSharing.o
	$(CXX) -c testSecretSharing.cpp
	$(CXX) -o testSS testSecretSharing.o ../secretSharing.o -lcrypto
	chmod u+x testSS


clean:
	rm -f test testSS test2  *~ *.o
