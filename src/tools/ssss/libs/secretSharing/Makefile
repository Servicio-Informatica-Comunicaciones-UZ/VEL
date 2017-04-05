CXX = g++


all: build


build: secretsharing secretsharer


secretsharing: secretSharing.cpp secretSharing.h
	$(CXX) -c secretSharing.cpp


secretsharer: secretSharer.cpp secretSharer.h
	$(CXX) -c secretSharer.cpp

clean:
	rm -f *~ *.o
