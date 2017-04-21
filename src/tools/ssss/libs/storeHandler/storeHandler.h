/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/


#ifndef __STOREHANDLER__
#define __STOREHANDLER__

#include <iostream>
#include <cstring>
#include <string>
#include <time.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "aux.h"

using namespace std;




//Errcodes
//0x00 es Ok, pero está definido en aux
#define ST_NO_DEVICE             0x02
#define ST_NOT_FOUND             0x03
#define ST_NO_PWD                0x04
#define ST_BAD_PWD               0X05
#define ST_NOT_LOGGED_IN         0X06
#define ST_LOGIN_ERROR           0X07
#define ST_PWD_TOO_LONG          0X08
#define ST_FORMAT_ERROR          0X09
#define ST_BLOCK_DELETION_ERROR  0X0A
#define ST_DATA_OVERFLOW         0X0B
#define ST_BLOCK_NUM_ERROR       0X0C
#define ST_BLOCK_WRITE_ERROR     0X0D
#define ST_BLOCK_READ_ERROR      0X0E
#define ST_NO_FREE_BLOCKS        0X0F
#define ST_OUT_OF_MEMORY         0x10
#define ST_CHECKSUM_ERROR        0x11
#define ST_ENCRYPT_ERROR         0x12
#define ST_DECRYPT_ERROR         0x13
#define ST_NOT_A_DIR             0x14



#define MAX_UNIX_PATH_LEN        4096
#define ST_MAX_PASS_LEN   127

#define MAX_NUM_BLOCKS 256



class StoreHandler
{
 public:
  
  StoreHandler();
  ~StoreHandler();
  
  int init(const char *  devicePath);

  int format(const char * newPwd);
  int login(const char *pwd); //Store is read on login
  int logout (void);
  int isLogged(void);
  
  int setPassword(const char *pwd);

  int listBlocks(unsigned char type,  int ** retArr, int * len);
  int writeBlock(const unsigned char * data, int dlen, unsigned char type, int ciphered, int bnum=-1);
  int readBlock(int bnum, unsigned char ** retblock, int * retlen) ;
  int deleteBlock(const int bnum);

  //Writes the current state of the store to the device, overwriting
  //the previous. Must be called explicitly to persist changes. Called
  //on logout
  int sync();
  
  static const int maxBlockData = 10224;
  

private:
  char * storePath;
  char * currPwd;

  static const int clauerBlockSize = 10240;
  
  static const char * storeFilename;
  
  static const char * header;
  
  typedef struct{
    char header[8];
    char data[maxBlockData];
    char trailer[8];
  } Block;  //10240


  typedef struct{
    unsigned char type;
    unsigned char ciphered;
    unsigned char magic;
    unsigned char reserved[125];
    Block data; //Will be ciphered
  } FileBlock; //10368, multiple of 16 (bytes, 128 bits), AES block size, we use no padding //Specific block for my storage handler, has a header, 
  
  
  typedef struct{
    char magicHeader[8];
    unsigned char  digestLen;   //Bytes que ocupa el hash
    unsigned char  digest[32];  //hash de todo el struct con el campo digest a cero  //Cabe hasta un sha256
    unsigned char  reserved[128];    
  } PublicHeader;
  
  
  typedef struct{
    char magicHeader[18]; // must match 0x00 16 random bytes 0x00
    unsigned char  digestLen;   //Bytes que ocupa el hash
    unsigned char  digest[32];  //hash de todo el struct con el campo digest a cero  //Cabe hasta un sha256
    unsigned int   nBlocks;     
    unsigned char  reserved[120];    
  } PrivateHeader; //len: 176, multiple of 16 (AES block size)


  PublicHeader  publicHeader;
  PrivateHeader privateHeader;
  FileBlock * blocks[MAX_NUM_BLOCKS];
  


  //Reads the Store from a file, deciphers it and puts it in memory
  int loadStore();

  //Writes the store to a file
  int persistStore();

  int resetPublicHeader();
  
  int checkPublicHeader(char * storefilePath);
  
  int checkPrivateHeader(char * storefilePath, char * pwd);

  PrivateHeader * getPrivateHeader(char * storefilePath, char * pwd);
  
};





#endif //__STOREHANDLER__
