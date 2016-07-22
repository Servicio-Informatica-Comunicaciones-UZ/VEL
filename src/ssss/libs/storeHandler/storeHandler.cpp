/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/

#include "storeHandler.h"




const char * StoreHandler::storeFilename = "vtUJI.store";

const char * StoreHandler::header = "\x00\xFF\xDE\xAD\xBE\xEF\xFF\x00";



StoreHandler::StoreHandler()
{  
  storePath   = NULL; //If NULL means not init.
  currPwd     = NULL; //If NULL means not logged in or not formatted
  
  for(int i = 0; i < MAX_NUM_BLOCKS; i++){
    blocks[i] = NULL;
  }
}




StoreHandler::~StoreHandler()
{
  if(storePath)
    free(storePath);
  if(currPwd){
    freeSecureString(currPwd, ST_MAX_PASS_LEN);
  }
  
  for(int i = 0; i < MAX_NUM_BLOCKS; i++)
    if(blocks[i] != NULL)
      free(blocks[i]);
}





int StoreHandler::resetPublicHeader(){
  
  //Set magic header of the public header
  memcpy(&publicHeader.magicHeader, header,8);
  
  //Digest will be a sha256
  publicHeader.digestLen = 32;
  
  //Set reserved space and digest area to zero
  memset(&publicHeader.digest, 0, 32+128);

  return _OK;
}



int StoreHandler::checkPublicHeader(char * storefilePath){
  
  PublicHeader * pheader = NULL;
  unsigned char * file;
  int storeSize = 0;
  int hashlen;
  unsigned char * readHash;
  
  
  pheader = (PublicHeader *) fetchBlock(storefilePath, 0, sizeof(PublicHeader));
  
  if(pheader == NULL){
    cerr<<"Error reading store public header"<<endl;
    return ST_NOT_FOUND;
  }

  //Checking public magic header
  if(memcmp(&pheader->magicHeader,header,8) != 0){
    cerr<<"Error: file doesn't seem to be a store"<<endl;
    return ST_NOT_FOUND;
  }


  //Read whole file to a buffer
  storeSize = sizeofFile(storefilePath);
  if(storeSize <=0)
    return ST_BLOCK_READ_ERROR;
  
  file = fetchBlock(storefilePath, 0, storeSize);

  //Reset public hash value on the buffer (skip the magic header + size of digest 8+1)
  memset(&file[8+1], 0,32);
  
  //Compare hash
  readHash = sha256digest(file,storeSize, &hashlen);

  if(memcmp(readHash,&pheader->digest,hashlen) != 0){
    cerr<<"Error: whole store hash doesn't match the expected one";
    return ST_CHECKSUM_ERROR;
  }
  
  free(pheader);
  free(file);
  free(readHash);
  
  return _OK;
}



StoreHandler::PrivateHeader * StoreHandler::getPrivateHeader(char * storefilePath, char * pwd){

  PrivateHeader * ciphered = NULL;
  PrivateHeader * pheader  = NULL;
  int outlen;

  Cipher * c = new Cipher();


  //Read private header (skip sizeof(PublicHeader) bytes )
  ciphered = (PrivateHeader *) fetchBlock(storefilePath, sizeof(PublicHeader), sizeof(PrivateHeader));
  if(ciphered == NULL){
    cerr<<"Error reading store private header"<<endl;
    return NULL;
  }
  
  //Decrypt private header
  c->init(pwd);
  pheader = (PrivateHeader *) c->decrypt((unsigned char *) ciphered, (int) sizeof(PrivateHeader),&outlen);
  if(pheader == NULL){
    cerr<<"Error decrypting store private header"<<endl;
    free(ciphered);
    return NULL;
  }
  free(ciphered);
  
  /*
  cout<<"MN: "<<bin2hex((unsigned char *) &pheader->magicHeader,18)<<endl;
  cout<<"DigestLen: "<<(int)pheader->digestLen<<endl;
  cout<<"Digest: "<<bin2hex((unsigned char *) &pheader->digest,32)<<endl;
  cout<<"nBlocks: "<<pheader->nBlocks<<endl;
  cout<<"Reserved: "<<bin2hex((unsigned char *) &pheader->reserved,120)<<endl;
  */
  
  return pheader;
}




int StoreHandler::checkPrivateHeader(char * storefilePath, char * pwd){
  
  PrivateHeader * pheader  = NULL;
  unsigned char * buffer;
  unsigned char * ciphblocks;
  unsigned char * readHash;
  int hashlen;
  

  //Get and decrypt the header
  pheader = getPrivateHeader(storefilePath,pwd);
  if(pheader == NULL)
    return ST_DECRYPT_ERROR;
  
  //Check magic number
  for(int i=0; i<18; i++){
    if(i==0 || i==17){
      if(pheader->magicHeader[i] != 0){
        cerr<<"Error: file doesn't seem to be a store or bad password"<<endl;
        return ST_BAD_PWD;
      }
    }else if(pheader->magicHeader[i] == 0){
      cerr<<"Error: file doesn't seem to be a store or bad password"<<endl;
      return ST_BAD_PWD;
    }
  }
  
  if(pheader->nBlocks<0)
    return ST_BLOCK_NUM_ERROR;
  
  //Build validation buffer (now we know the size of the block list, we only read what we expect to find)
  buffer = (unsigned char *) malloc(sizeof(PrivateHeader)+pheader->nBlocks*sizeof(FileBlock));
  if (!buffer){
    cerr<<"Out of memory"<<endl;
    return ST_OUT_OF_MEMORY;
  }
  
  //Copy decrypted private header
  memcpy(buffer, pheader, sizeof(PrivateHeader));
  
  //Reset digest value field (memset to zero starting after the magicnumber and the digestsize)
  memset(&buffer[18+1], 0, 32);

  //Fetch all blocks, ciphered.
  if(pheader->nBlocks>0){
    ciphblocks = fetchBlock(storefilePath,
                            sizeof(PublicHeader)+sizeof(PrivateHeader),
                            pheader->nBlocks*sizeof(FileBlock));
  
    if(ciphblocks == NULL){
      cerr<<"Error reading store"<<endl;
      return ST_NOT_FOUND;
    }
  
    //Copy encrypted blocks to buffer
    memcpy(buffer+sizeof(PrivateHeader), ciphblocks, pheader->nBlocks*sizeof(FileBlock));
    free(ciphblocks);
  }
  
  //Calculate hash of read blocks and plain header
  readHash = sha256digest(buffer,sizeof(PrivateHeader)+pheader->nBlocks*sizeof(FileBlock), &hashlen);

  //Check hash
  if(memcmp(readHash,&pheader->digest,hashlen) != 0){
    cerr<<"Error: private check hash doesn't match the expected one";
    return ST_CHECKSUM_ERROR;
  }
  
  free(pheader);
  free(buffer);
  
  return _OK;
}






//Reads the Store from a file and deciphers it
int StoreHandler::loadStore(){
  /*
  PublicHeader  publicHeader;
  PrivateHeader privateHeader;
  FileBlock * blocks[MAX_NUM_BLOCKS];
  */
  PrivateHeader * pheader;
  FileBlock * ciphblock;
  int outlen;
  Block * block;
  
  Cipher * c = new Cipher();
  
  c->init(currPwd);
  
  //Check the public header
  if ( checkPublicHeader(storePath) != _OK ){
    cerr<<"Store not found or corrupted"<<endl;
    return ST_NOT_FOUND;
  }

  cerr<<"Checked public header"<<endl;
  
  //Public header is not trustable, and all of the data is generated
  //on write, so we don't read it and simply reset it on every
  //load. Besides, it has been checked on init.
  resetPublicHeader();
  
  //Validate private header
  if(checkPrivateHeader(storePath, currPwd) != _OK)
    return ST_BLOCK_READ_ERROR;

  cerr<<"Checked private header"<<endl;
  
  
  //Read private header into the attribute
  pheader = getPrivateHeader(storePath,currPwd);
  if(pheader == NULL)
    return ST_DECRYPT_ERROR;
  memcpy(&privateHeader,pheader,sizeof(PrivateHeader));
  
  
  // Fetch each fileblock. Only read the number of blocks declared on
  // the private header (to exclude any non-encrypted piggybacker
  // blocks that might appear)
  for(int i=0; i < pheader->nBlocks; i++){
    ciphblock = (FileBlock *) fetchBlock(storePath,
                           sizeof(PublicHeader)+sizeof(PrivateHeader)+i*sizeof(FileBlock),
                           sizeof(FileBlock));
    //Check magic number on plain header
    if(ciphblock == NULL || ciphblock->magic != 42){
      cerr<<"Error reading store"<<endl;
      return ST_NOT_FOUND;
    }

    //If this filebock is ciphered, decipher it
    if(ciphblock->ciphered != 0){      
      block = (Block *) c->decrypt( (unsigned char *) &ciphblock->data, sizeof(Block),&outlen);
      if(block == NULL){
        cerr<<"Error decrypting block "<<i<<endl;
        return ST_ENCRYPT_ERROR;
      }
      //I'm aware there is no magic header on the ciphered block part
      //to check proper decryption, but since integrity has been
      //checked through the private header digest, no one could tamper
      //the blocks and thus, the block must be properly ciphered with
      //the password.

      //Copy deciphered content into the FileBlock, to be stored on
      //the proper class struct
      memcpy(&ciphblock->data, block, sizeof(Block));
      free(block);
    }
    
    //The fetched block is stored on the block array
    blocks[i] = ciphblock;
  }
  
  return _OK;
}






int StoreHandler::persistStore(){
  
  //Accumulate here all the data to be written: public header,
  //ciphered private header and ciphered blocks. Digests must be calculated.
  unsigned char * buffer;
  unsigned int bufferLen = sizeof(PublicHeader)+sizeof(PrivateHeader)+privateHeader.nBlocks*sizeof(FileBlock);  

  int bufferPos = sizeof(PublicHeader)+sizeof(PrivateHeader); //Start after the headers (points to the next empty char)

  char * cipheredBuffer;
  int outlen;

  char * digest;
  
  Cipher * c = new Cipher();
  
  //If no password or device set, fail
  if (isLogged() == _FALSE)
    return ST_NOT_LOGGED_IN;
  
  
  //Reserve serialized file space
  buffer = (unsigned char *) malloc(bufferLen);
  if (!buffer){
    cerr<<"Out of memory"<<endl;
    return ST_OUT_OF_MEMORY;
  }
  
  c->init(currPwd);
  
  //Cipher blocks that have to be ciphered and write them to buffer
  for(int i = 0; i < MAX_NUM_BLOCKS; i++)
    if(blocks[i] != NULL){

      //Copy the block, with data in plaintext
      memcpy(&buffer[bufferPos],blocks[i],sizeof(FileBlock));
      
      //If it needs to be ciphered
      if(blocks[i]->ciphered != 0){
        
        cipheredBuffer = (char *) c->encrypt((unsigned char *) &blocks[i]->data, sizeof(Block),&outlen);
        if(cipheredBuffer == NULL){
          cerr<<"Error encrypting store block"<<endl;
          free(cipheredBuffer);
          return ST_BLOCK_WRITE_ERROR;
        }

        //Overwrite the data field of the FileBlock with the encrypted one (last position+type+ciphered+magic+resvd)
        memcpy(&buffer[bufferPos]+128, cipheredBuffer, sizeof(Block));
        
        free(cipheredBuffer);
      }
            
      bufferPos += sizeof(FileBlock);
    }
  
  
  //Reset private hash
  memset(&privateHeader.digest,0,32);

  //Copy plain private header to buffer for hashing
  memcpy(buffer+sizeof(PublicHeader),&privateHeader,sizeof(PrivateHeader));  
  
  //Calculate private digest (plain privateHeader + ciphered/plain blocks)
  digest = (char *) sha256digest(buffer+sizeof(PublicHeader),
                        sizeof(PrivateHeader)+privateHeader.nBlocks*sizeof(FileBlock),
                        &outlen);
  if(digest == NULL){
    cerr<<"Error calculating digest"<<endl;
    return ST_BLOCK_WRITE_ERROR;
  }
  memcpy(&privateHeader.digest,digest,32);
  free(digest);
  
  //Encrypt private header
  cipheredBuffer = (char *) c->encrypt((unsigned char *) &privateHeader, sizeof(PrivateHeader),&outlen);
  if(cipheredBuffer == NULL){
    cerr<<"Error encrypting private header"<<endl;
    free(cipheredBuffer);
    return ST_BLOCK_WRITE_ERROR;
  }
  
  //Copy encrypted private header to buffer
  memcpy(buffer+sizeof(PublicHeader),cipheredBuffer,sizeof(PrivateHeader));
  free(cipheredBuffer);
  
  
  //Reset public hash
  memset(&publicHeader.digest,0,32);
  
  //Copy public header to buffer
  memcpy(buffer,&publicHeader,sizeof(PublicHeader));
  
  //Calculate full file hash
  digest = (char *) sha256digest(buffer,
                        sizeof(PublicHeader)+sizeof(PrivateHeader)+privateHeader.nBlocks*sizeof(FileBlock),
                        &outlen);
  if(digest == NULL){
    cerr<<"Error calculating digest"<<endl;
    return ST_BLOCK_WRITE_ERROR;
  }
  memcpy(&publicHeader.digest,digest,32);
  free(digest);
  
  //Write the public digest to the buffer
  memcpy(buffer,&publicHeader,sizeof(PublicHeader));

  cerr<<"Public digest: "<<bin2hex((unsigned char *)digest,32)<<endl;
    
  //Write stores to file
  if(writeFile(storePath, buffer, bufferLen) != _OK){
    cerr<<"Error writing store file"<<endl;
    return ST_BLOCK_WRITE_ERROR;
  }
  
  
  //Read written file
  memset(buffer,0,bufferLen);
  buffer = fetchBlock(storePath, 0, bufferLen);

  //Reset public hash area
  memset(&buffer[8+1],0,32);
  
  
  //Hash file
  digest = (char *) sha256digest(buffer,bufferLen,&outlen);
  if(digest == NULL){
    cout<<"Error calculating digest of write validation"<<endl;
    return ST_BLOCK_WRITE_ERROR;
  }

  cerr<<"Public digest (from struct):   "<<bin2hex((unsigned char *)publicHeader.digest,32)<<endl;
  cerr<<"Public digest (from readfile): "<<bin2hex((unsigned char *)digest,32)<<endl;

  
  //Compare that write went fine
  if(memcmp(digest, &publicHeader.digest, outlen != 0)){
    cout<<"Error calculating digest of write validation"<<endl;
    return ST_BLOCK_WRITE_ERROR;
  }
  
  free(digest);    
  free(buffer);
  
  return _OK;
}



int  StoreHandler::sync(){
  
  return persistStore();
}










int StoreHandler::init(const char * devicePath)
{
  struct stat info;

  int storePathLen;
  
  if(!devicePath || strnlen(devicePath, MAX_UNIX_PATH_LEN) == 0){
    cerr<<"Device name not set"<<endl;
    return ST_NO_DEVICE; 
  }

  cerr<<"Device: "<<devicePath<<" -->"<<strlen(devicePath)<<endl;
  
  if(strnlen(devicePath, MAX_UNIX_PATH_LEN) >= MAX_UNIX_PATH_LEN-strlen(storeFilename)-1){
    cerr<<"Device name too long"<<endl;
    return ST_NO_DEVICE; 
  }
  
  storePathLen = strnlen(devicePath, MAX_UNIX_PATH_LEN)+1+strlen(storeFilename);
   
  //Copy the route of the store file and concat the expected filename  
  storePath = (char *) malloc(storePathLen+1);
  if (storePath == NULL){
    cerr<<"Out of memory"<<endl;
    return ST_OUT_OF_MEMORY;
  }

  //Causes a memory leak that I still don't understand (nothing to do
  //with the sizeo of the buffer. DON'T USE)
  //strncpy(storePath, devicePath, MAX_UNIX_PATH_LEN);
  memcpy(storePath, devicePath, strnlen(devicePath, MAX_UNIX_PATH_LEN)+1);
  strcat(storePath, "/");
  strcat(storePath, storeFilename);

  cerr<<"Set device name and store path: "<<storePath<<" -->"<<strlen(storePath)<<endl;

  //Check if devicePath exists (but not the store, as it might not exist and need formatting)
  if( stat( devicePath, &info ) != 0 ) {
    cerr<<"Cannot access device path: "<<devicePath<<endl;
    return ST_NOT_FOUND;
  }
  else if( !(info.st_mode & S_IFDIR) ){
    cerr<<"Device path not a directory: "<<devicePath<<endl;
    return ST_NOT_A_DIR;
  }
  
  return _OK;
}


int StoreHandler::login(const char *pwd)
{
  char * aux;
  
  //cerr<<"Password introducido ("<<pwd<<"): ";
  
  //for (int zz=0; zz<strlen(pwd);zz++)
  //	cerr<<std::hex<<((short)pwd[zz]);
  // cerr<<endl;
  
  if (!storePath)
    return ST_NO_DEVICE;


  aux = allocateSecureString(ST_MAX_PASS_LEN);
  if (!aux)
    return ST_OUT_OF_MEMORY;
  memcpy(aux, pwd, strnlen(pwd, ST_MAX_PASS_LEN)+1);
  aux[ST_MAX_PASS_LEN] = '\0';       //Si el pass desbordara la long max, no se escribiria el \0
  
  if(aux == NULL || strlen(aux) == 0)
    return ST_NO_PWD;
  
  currPwd=aux;
  
  
  //Read the store from the file, decipher, check and build the memory structures
  if (loadStore() != _OK){
    if (currPwd){
      freeSecureString(currPwd, ST_MAX_PASS_LEN);
      currPwd = NULL; 
    }
    return ST_BAD_PWD;  
  }
  
  return _OK;
}





int StoreHandler::logout(void)
{
  
  //If logging out, force a sync (although it could have been synced earlier)
  if( this->sync() != _OK )
    return ST_BLOCK_WRITE_ERROR;
    
  if(currPwd)
    freeSecureString(currPwd, ST_MAX_PASS_LEN);
  
  currPwd = NULL;
  
  return _OK;
}






int StoreHandler::setPassword(const char *pwd)
{

  char *aux;
  
  if (isLogged() == _FALSE)
    return ST_NOT_LOGGED_IN;
  
  if(pwd==NULL || strnlen(pwd, ST_MAX_PASS_LEN) ==  0)
    return ST_NO_PWD;
	
  aux = allocateSecureString(ST_MAX_PASS_LEN);
  if (!aux)
    return ST_OUT_OF_MEMORY;
  aux[0]=0;
	
  memcpy(aux, pwd, strnlen(pwd, ST_MAX_PASS_LEN)+1);
  
  if (aux[0] == 0 || aux[ST_MAX_PASS_LEN] != '\0'){
    cerr<<"Password demasiado largo o vacio"<<endl;
    freeSecureString(aux, ST_MAX_PASS_LEN);
    return ST_BAD_PWD;
  }
  
  //Store new password. Session keeps open
  freeSecureString(currPwd, ST_MAX_PASS_LEN);
  currPwd = aux;
  
  return _OK;
}



int StoreHandler::format(const char *pwd){
  
  char *aux;
  
  if (! storePath)
    return ST_NO_DEVICE;

  
  if(pwd == NULL | strnlen(pwd,ST_MAX_PASS_LEN+1) == 0)
    return ST_NO_PWD;

  aux = allocateSecureString(ST_MAX_PASS_LEN);
  if (!aux)
    return ST_OUT_OF_MEMORY;
  aux[0]=0;

  memcpy(aux, pwd, strnlen(pwd, ST_MAX_PASS_LEN)+1);
  
  if (aux[ST_MAX_PASS_LEN] != '\0'){
    freeSecureString(aux, ST_MAX_PASS_LEN);
    return ST_PWD_TOO_LONG;
  }
    
  //Set the default data for the public header
  resetPublicHeader();
  
  
  //Set magic header of the private header (random, to enhance cbc security)
  srand(time(NULL));
  for(int i = 0; i < 18; i++)
    privateHeader.magicHeader[i] = (rand() % 255)+1; //No zero allowed
  privateHeader.magicHeader[0]  = '\x00';
  privateHeader.magicHeader[17] = '\x00';
  
  //Digest will be a sha256
  privateHeader.digestLen = 32;
  
  //Set digest area to zero
  memset(privateHeader.digest, 0,32);

  //Set initial number of blocks
  privateHeader.nBlocks = 0;
  
  //Set reserved area to zero
  memset(privateHeader.reserved, 0,128);
  
  //Erase all blocks
  for(int i = 0; i < MAX_NUM_BLOCKS; i++)
    if(blocks[i] != NULL){
      free(blocks[i]);
      blocks[i] = NULL;
    }
  
  //Store password as the password to be used
  if(currPwd != NULL)
    freeSecureString(currPwd, ST_MAX_PASS_LEN);
  currPwd = aux;
  
  return _OK;
}



int StoreHandler::isLogged(void)
{
  if (! storePath)
    return _FALSE;
  
  if(!currPwd)
    return _FALSE;
  
  return _TRUE;
}





//SecretSharing blocktype: 0x0f
//Returns block nums of type blockType
int StoreHandler::listBlocks(unsigned char blockType,  int ** retArr, int * len){
  
  int * blocklist;
  int numblocks;
  
  if (isLogged() == _FALSE)
    return ST_NOT_LOGGED_IN;
  
  blocklist = (int *) malloc(MAX_NUM_BLOCKS *sizeof(int));
  numblocks = 0;
  
  for(int i = 0; i < MAX_NUM_BLOCKS; i++)
    if(blocks[i] != NULL)
      if(blocks[i]->type == blockType)
        blocklist[numblocks++] = i;
  
  *retArr = blocklist;
  *len    = numblocks;
  
  return _OK;
}




int StoreHandler::deleteBlock(const int bnum){
  
  if (isLogged() == _FALSE)
    return ST_NOT_LOGGED_IN;

  if(bnum < 0 || bnum >MAX_NUM_BLOCKS)
    return ST_BLOCK_DELETION_ERROR;

  if(blocks[bnum] == NULL)
    return ST_BLOCK_DELETION_ERROR;
  
  free(blocks[bnum]);
  blocks[bnum] = NULL;
  
  //Decrease number of blocks
  privateHeader.nBlocks--;
  
  return _OK;
}





//If bnum == -1 (default), First empty slot is used
int StoreHandler::writeBlock(const unsigned char * data, int dlen, unsigned char blockType, int ciphered, int bnum){

  FileBlock fblock;
  
  int numblock = bnum;
  
  
  if (isLogged() == _FALSE)
    return ST_NOT_LOGGED_IN;
  
  if(dlen > maxBlockData || dlen <=0)
    return ST_DATA_OVERFLOW;
  
  if(bnum < -1)
    return ST_BLOCK_NUM_ERROR;
  
  
  srand((unsigned int)time(NULL));
  
  //Block initialization (clauer legacy code, which identified the ciphered block by the random value,ranged)    
  if(ciphered == _TRUE)
    fblock.data.header[0] = (rand()%85)+170;
  else
    fblock.data.header[0] = (rand()%85)+85;     
  fblock.data.header[1] = blockType;
  
  //Set the block magic number
  fblock.magic = 42;
  
  //Set the block type
  fblock.type = blockType;
  
  //Set whether the block will be ciphered
  fblock.ciphered = 0;
  if(ciphered == _TRUE)
    fblock.ciphered = 1;

  //Set reserved area to zero
  memset(&fblock.reserved, 0, 125);
  
  
  for(int i=2;i<8;i++){                  //6 Bytes. Reserved
    fblock.data.header[i] = 0;
  }
  
  for(int i=0;i<8;i++){                  //8 bytes. Random salt
    fblock.data.trailer[i] = rand() % 256;
  }

  //zero data region
  memset(&fblock.data.data, 0, maxBlockData);
  
  
  //Copy data content to Block
  memcpy(&fblock.data.data, data, dlen);
  

  //cout<<"FBLOCK: "<<bin2hex((unsigned char *)&fblock,sizeof(FileBlock))<<endl;
  
  //Guess first free slot
  if(bnum == -1){
    for(numblock = 0; numblock < MAX_NUM_BLOCKS; numblock++)
      if(blocks[numblock] == NULL)
        break;
    if(numblock >= MAX_NUM_BLOCKS)
      return ST_NO_FREE_BLOCKS;
  }

  //If overwriting, it will be already allocated.
  if(blocks[numblock] == NULL)
    blocks[numblock] =  (FileBlock *) malloc(sizeof(FileBlock));
  if (!blocks[numblock]){
    cerr<<"Out of memory"<<endl;
    return ST_OUT_OF_MEMORY;
  }
 
  //Copy FileBlock to block list (not ciphered yet)
  memcpy(blocks[numblock], &fblock, sizeof(FileBlock));

  //Increase number of blocks
  privateHeader.nBlocks++;

  return _OK;
}







int StoreHandler::readBlock(int bnum, unsigned char ** retblock, int * retlen){
  
  Block * inblock;
  
  if (isLogged() == _FALSE)
    return ST_NOT_LOGGED_IN;
 
  if(bnum < -1)
    return ST_BLOCK_NUM_ERROR;

  if(blocks[bnum] == NULL)
    return ST_BLOCK_READ_ERROR;
  

  inblock = new Block;

  //Reset buffer where the block will be written
  memset(inblock,0,sizeof(Block));

  //Copy 
  memcpy(inblock, &blocks[bnum]->data, sizeof(Block));

  //cerr<<"----- clauerHandler. bloque leido:"<<endl<<bin2hex((unsigned char *)inblock,clauerBlockSize)<<endl;
  
  * retblock = (unsigned char *) inblock;
  * retlen   = clauerBlockSize;
  
  //cerr<<"----- clauerHandler. bloque leido:"<<endl<<bin2hex(retblock,retlen)<<endl;

  return _OK;
}








