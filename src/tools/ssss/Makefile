CXX = g++ 

#We build it statci to avoid compatibility issues
STATIC_FLAGS = # -static -static-libgcc

#They must be added to the end, so ld will lookup earlier undefined symbols. Won't lookup later symbols. 
STATIC_LIBS  =  -lcrypto -lpthread

#Includes will be taken starting from this directory
LIBS = ./libs



INCLUDES = -I $(LIBS)/ -I $(LIBS)/Aux

LDPATHS =  -lcrypto


DEFINES = -DLINUX


OBJECTS = $(LIBS)/secretSharing/*.o  \
										$(LIBS)/storeHandler/*.o   \
										$(LIBS)/Aux/*.o


all: ssOperations



ssOperations: ssOperations.cpp 
	make -C $(LIBS)/Aux/
	make -C $(LIBS)/storeHandler/
	make -C $(LIBS)/secretSharing/
	$(CXX) $(STATIC_FLAGS)  -o ssOperations ssOperations.cpp $(INCLUDES) $(DEFINES) $(LDPATHS) $(OBJECTS) $(STATIC_LIBS)
	chmod u+x ssOperations


clean: 
	make -C $(LIBS)/Aux/              clean
	make -C $(LIBS)/LIBRT/            clean
	make -C $(LIBS)/storeHandler/    clean
	make -C $(LIBS)/secretSharing/    clean
	rm -f *.o *~ ssOperations
