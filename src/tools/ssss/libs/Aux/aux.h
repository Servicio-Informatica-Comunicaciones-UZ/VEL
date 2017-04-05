/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/




#ifndef __AUXFUNCTIONS__
#define __AUXFUNCTIONS__

#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <stdio.h>
#include <sys/mman.h>
#include <openssl/evp.h>
#include <openssl/aes.h>
#include <openssl/sha.h>
#include <string>
#include <cstring>

#define _TRUE  1
#define _FALSE 0
#define _OK    1
#define _ERR   0


using namespace std;

//Aux functions

char * allocateSecureString(const int size);
int  freeSecureString(char * buffer, const int size);
char * bin2hex(unsigned char *bin, int l);

unsigned char * fetchBlock(char * filename, unsigned int start, unsigned int length);
int writeFile(char * filename, unsigned char * data, unsigned int length);
int sizeofFile(char * filename);

unsigned char * sha256digest(unsigned char * text, int length,  int * outlength);

class Cipher {
public:
  
  Cipher();
  ~Cipher();


  int init(string password);
  
  unsigned char * encrypt(unsigned char * plaintext, int length, int * outlength);
  unsigned char * decrypt(unsigned char * ciphertext, int length, int * outlength);
  
  
private:

  EVP_CIPHER_CTX enCtx, deCtx;
};

  
#endif //__AUXFUNCTIONS__
