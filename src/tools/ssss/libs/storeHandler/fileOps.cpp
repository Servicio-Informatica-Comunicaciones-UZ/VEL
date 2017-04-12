
#include "fileOps.h"




StoreFile::StoreFile()
{  
  storePath = NULL;
  currPwd = NULL;
}







StoreFile::~StoreFile()
{
  if(storePath)
    free(storePath);
  if(currPwd){
    freeSecureString(currPwd, CLUI_MAX_PASS_LEN);
  }
}





