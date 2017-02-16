/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/

#ifndef __FILEOPS__
#define __FILEOPS__

#include <iostream>
#include <string.h>
#include <string>
#include <time.h>




class StoreFile
{
 public:
  
  StoreFile();
  ~StoreFile();

  // TODO: define file header, with salted magic number to check decryption, number of blocks and crc. Encrypt with AES. separately encrypt header and blocks


  //Checks public header magic number, size and hash
  int exists();
  
  
  //Checks private header magic number, size and hash
  int checkPassword();




}


#endif //__FILEOPS__
