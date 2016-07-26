
#include "aux.h"


using namespace std;


/************************** Support Functions ******************************/


char * bin2hex(unsigned char *bin, int l){

  unsigned char * ret;
  char digitos[] = "0123456789ABCDEF";

  ret = (unsigned char *) malloc ((l*2+1)*sizeof(char));

  for (int i = 0; i < l; i++) {
    ret[2*i]=  digitos[bin[i] >> 4];
    ret[2*i+1]=digitos[bin[i] & 0xf];
  }
  ret[2*l]= 0;

  return (char *) ret;
}



char * allocateSecureString(const int size){

  char * aux;	
  
  aux = new char[size+1];  //reservamos el buffer
  if ( ! aux )
    return 0;
  for (int z=0;z<=size;z++)   //Limpiamos el buffer
    aux[z] = 'z';  //poner un /0 tras las pruebas
  aux[size] = '\0';		

  if ( mlock(aux, size+1)!=0){  //bloqueamos el buffer
    delete [] aux;	
    return 0;
  }

  return aux;
}



int  freeSecureString(char * buffer, const int size){

  char * aux = buffer;

  for (int z=0;z<=size;z++)   //Limpiamos el buffer
    aux[z] = 'z';	//poner un /0 tras las pruebas		 
  aux[size] = '\0';		

  if ( munlock(aux, size+1)!=0)  //Lo desbloqueamos para el swap (ahora que no tiene info secreta)
    return 1;

  delete [] aux;

  buffer = NULL;
  return 0;

}



int sizeofFile(char * filename){
  
  ifstream fpointer;
  unsigned int fsize;
  
  fpointer.open(filename, ios::binary | ios::ate);   //Open the file with the pointer at the end
  fsize = fpointer.tellg();
  fpointer.close();
  
  return fsize;
}



unsigned char * fetchBlock(char * filename, unsigned int start, unsigned int length){

  unsigned char * ret;
  unsigned int fsize;
  ifstream fpointer;
  
  if(length<=0 || start<0 || filename == NULL){
    cerr<<"FetchBlock: Bad parameters"<<endl;
    return NULL;
  }
  
  //Determine size of file
  fsize = sizeofFile(filename);
  
  if(start+length > fsize){
    cerr<<"Overflow: "<<start<<"+"<<length<<" > "<<fsize<<endl;
    return NULL;
  }


  ret =  (unsigned char*) malloc(length);
  if(ret == NULL){
    cerr<<"Out of memory error."<<endl;
    return NULL;
  }
  
  fpointer.open(filename, ios::binary);
  
  //Go to the starting point of the block
  fpointer.seekg(start,ios::beg);
  
  fpointer.read( (char *) ret,length);
    
  fpointer.close();

  return ret;
}




int writeFile(char * filename, unsigned char * data, unsigned int length){
  
  ofstream fpointer;
  
  if(filename == NULL | strlen(filename) <= 0){
    cerr<<"writeFile: No filename"<<endl;
    return _ERR;
  }
  if(data == NULL){
    cerr<<"writeFile: data null"<<endl;
    return _ERR;
  }
    
  fpointer.open(filename, ios::binary | ios::out | ios::trunc);

  if (!fpointer.is_open()){
    cerr<<"writeFile: file open error ("<<filename<<")"<<endl;
    return _ERR;
  }
  
  fpointer.write( (char *) data,length);

  if(!fpointer.good()){
    cerr<<"writeFile: write error ("<<endl;
    return _ERR;
  }
  
  fpointer.close();
  
  return _OK;
}








//Returned string is of SHA256LEN length

unsigned char * sha256digest(unsigned char * text, int length,  int * outlength){

  unsigned char * hash;

  if(length<=0)
    return NULL;
  
  hash = (unsigned char*) malloc(SHA256_DIGEST_LENGTH);
  
  SHA256_CTX sha256;
  SHA256_Init(&sha256);
  SHA256_Update(&sha256, text, length);
  SHA256_Final(hash, &sha256);

  * outlength = SHA256_DIGEST_LENGTH;

  return hash;
}





Cipher::Cipher(){
  
}


Cipher::~Cipher(){

  if(&enCtx != NULL)
    EVP_CIPHER_CTX_cleanup(&enCtx);

  if(&deCtx != NULL)
    EVP_CIPHER_CTX_cleanup(&deCtx); 
}



int Cipher::init(string password){
  
  //unsigned char salt[8];
  //FILE * rnd;

  int i, rounds=5;
  unsigned char key[32], iv[32];
  
  /*
  if( (int) (rnd = fopen("/dev/random", "r")) <= 0){
    cerr<<"Error,Opening /dev/random"<<endl;
    return 1;
  }
  else{
    if(fread(salt,1,8,rnd) < 8){
      cerr<<"Error,reading from /dev/random"<<endl;
      return 1;
    }
    close(rnd);
  }
  */
  i = EVP_BytesToKey(EVP_aes_256_cbc(),EVP_sha256(),
                     NULL, (const unsigned char *) password.c_str(),password.length(),
                     rounds,key,iv);
  if(i != 32){
    cerr<<"Error,Incorrect key size generated:%d:"<<i<<endl;
    return 1;
  }
  
  EVP_CIPHER_CTX_init(&enCtx);
  EVP_EncryptInit_ex(&enCtx, EVP_aes_256_cbc(), NULL, key, iv);
  // Deactivating padding. Input data must always be a multiple of 16,
  // output data will always be the same size as the input
  EVP_CIPHER_CTX_set_padding(&enCtx,0);
  
  
  EVP_CIPHER_CTX_init(&deCtx);
  EVP_DecryptInit_ex(&deCtx, EVP_aes_256_cbc(), NULL, key, iv);
  EVP_CIPHER_CTX_set_padding(&enCtx,0); //DEactivate padding for the output
  
  return 0;
}



unsigned char * Cipher::encrypt(unsigned char * plaintext, int length, int * outlength){

  unsigned char * out;
  unsigned char buf[AES_BLOCK_SIZE];
  int outlen,flen;

  if(!EVP_EncryptInit_ex(&enCtx, NULL, NULL, NULL, NULL)){
    cerr<<"Error, init not called"<<endl;
    return NULL;
 	}

  out = (unsigned char*) malloc(length);
  if(out == NULL){
    cerr<<"Out of memory error.";
    return NULL;
  }
  
  if(!EVP_EncryptUpdate(&enCtx, out, &outlen, plaintext, length)){
    cerr<<"ERROR,ENCRYPR_UPDATE:"<<endl;
    return NULL;
		}

  //Should be empty, will complain if not because padding is 0
  if(!EVP_EncryptFinal_ex(&enCtx, buf, &flen)){
    cerr<<"\n ERROR,ENCRYPT_FINAL:";
    return NULL;
  }
  
  * outlength = outlen+flen;
  
  return out;	
}

unsigned char * Cipher::decrypt(unsigned char * ciphertext, int length, int * outlength){
  
  unsigned char * out;
  unsigned char buf[AES_BLOCK_SIZE];
  int outlen,flen;
  
  if(!EVP_DecryptInit_ex(&deCtx, NULL, NULL, NULL, NULL)){
    cerr<<"Error in DECinit:"<<endl;
    return NULL;
  }    
  
  out = (unsigned char*) malloc(length);
  if(out == NULL){
    cerr<<"Out of memory error.";
    return NULL;
  }
  
  if(!EVP_DecryptUpdate(&deCtx,out, &outlen, ciphertext, length)){
    cerr<<"Error,DECRYPT_UPDATE:"<<endl;
    return NULL;
		}

  //For some reason, even if data fits the block size, this call fails
  //and the returned length equals one block less, but the data is
  //properly deciphered and written. We return the corrected length
  if(!EVP_DecryptFinal_ex(&deCtx, buf, &flen)){
    //cerr<<"Error,DECRYPT_FINAL. Remember we used no padding. Plaintext length should have been multiple of 128bit"<<endl;
    //return NULL;
    flen = AES_BLOCK_SIZE; //16 byte, 128 bit block length
  }
  
  * outlength = outlen+flen;

  return out;
}

