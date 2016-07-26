CXX = g++

LIBDIR = ../..

INCLUDES = -I $(LIBDIR)/  \
           -I $(LIBDIR)/Aux

DEFINES= -DLINUX

all: test


test: test.cpp ../storeHandler.o
	$(CXX) -c	test.cpp $(INCLUDES) 
	$(CXX) -o test test.o $(DEFINES) $(LIBDIR)/Aux/aux.o ../storeHandler.o  -lcrypto
	chmod u+x test

clean:
	rm -f *.o *~ test
