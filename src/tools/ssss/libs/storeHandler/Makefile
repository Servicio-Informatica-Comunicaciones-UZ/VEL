CXX = g++

LIBDIR = ..

INCLUDES = -I $(LIBDIR)/  \
           -I $(LIBDIR)/Aux

DEFINES= -DLINUX

all: storehandler

storehandler: storeHandler.cpp storeHandler.h
	$(CXX) -c storeHandler.cpp $(INCLUDES) $(DEFINES)

clean:
	rm -f *.o *~
