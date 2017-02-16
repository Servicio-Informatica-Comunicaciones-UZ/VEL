#include <iostream>
#include <string.h>
#include <string>

#include "aux.h"
#include "../storeHandler.h"

using namespace std;

int main(void){
  
  int l = 8;
  int s = 0; 

  int ret;
  
  unsigned char * readStr = NULL;

  int * blocks;
  int nbl=0;
  
  StoreHandler * st = new StoreHandler();
  StoreHandler * st2 = new StoreHandler();
  StoreHandler * st3 = new StoreHandler();

  unsigned char * bl;
  int retlen;
  
  st->init("/home/paco/Escritorio/test");

  st->format("123clauer");

  if(st->isLogged()){
    cout<<"Is logged!!!"<<endl;
  }


  st->writeBlock((const unsigned char *)"holaquetal-cleartext",21,'\x0F',0);

  st->writeBlock((const unsigned char *)"holaquetal-ciphertext",22,'\x0F',1);

  st->writeBlock((const unsigned char *)"holaquetal-cleartext2",21,'\x0F',0);
  
  st->writeBlock((const unsigned char *)"holaquetal-ciphertext2",22,'\x0F',1);

  

  //List secret sharing blocks
  st->listBlocks('\x0f',&blocks,&nbl);
  cout<<"SS Blocks: ";
  for(int i=0;i<nbl;i++)
    cout<<blocks[i];
  cout<<endl;


  for(int i=0; i<4; i++){
    st->readBlock(i, &bl, &retlen);
    //  cerr<<"Block "<<i<<" content ("<<retlen<<"): "<<bin2hex(bl,retlen)<<endl;
    cerr<<"Block "<<i<<" content ("<<retlen<<"): "<<&bl[8]<<endl;
  }

  
  st->sync();

  st->setPassword("123clauer2");
  
  st->logout();
  
  
  cout<<"*********************************"<<endl;
    
  
  st2->init("/home/paco/Escritorio/test");

  if(!st2->isLogged()){
    cout<<"Not yet logged!!!"<<endl;
  }
  
  st2->login("123clauer2");


  if(st2->isLogged()){
    cout<<"Is logged!!!"<<endl;
  }


  for(int i=0; i<4; i++){
    st2->readBlock(i, &bl, &retlen);
    //  cerr<<"Block "<<i<<" content ("<<retlen<<"): "<<bin2hex(bl,retlen)<<endl;
    cerr<<"Block "<<i<<" content ("<<retlen<<"): "<<&bl[8]<<endl;
  }

  
  st2->deleteBlock(2);
  st2->deleteBlock(1);

  cout<<"After deleting..."<<endl;
  for(int i=0; i<4; i++){
    ret = st2->readBlock(i, &bl, &retlen);
    //  cerr<<"Block "<<i<<" content ("<<retlen<<"): "<<bin2hex(bl,retlen)<<endl;
    if(ret == _OK)
      cerr<<"Block "<<i<<" content ("<<retlen<<"): "<<&bl[8]<<endl;
    else
      cerr<<"Block "<<i<<" empty"<<endl;
  }
  
  //List secret sharing blocks
  st2->listBlocks('\x0f',&blocks,&nbl);
  cout<<"SS Blocks: ";
  for(int i=0;i<nbl;i++)
    cout<<blocks[i];
  cout<<endl;
  

  
  st2->logout();

  cout<<"*********************************"<<endl;


  st3->init("/home/paco/Escritorio/test");

  st3->login("123clauer2");

  
  if(st3->isLogged()){
    cout<<"Is logged!!!"<<endl;
  }
  
  
  //List secret sharing blocks
  st3->listBlocks('\x0f',&blocks,&nbl);
  cout<<"SS Blocks: ";
  for(int i=0;i<nbl;i++)
    cout<<blocks[i];
  cout<<endl;
  
  
  for(int i=0; i<nbl; i++){
    st3->readBlock(i, &bl, &retlen);
    //  cerr<<"Block "<<i<<" content ("<<retlen<<"): "<<bin2hex(bl,retlen)<<endl;
    cerr<<"Block "<<i<<" content ("<<retlen<<"): "<<&bl[8]<<endl;
  }

  
  st3->sync();
  
  st3->logout();
  
  
  



  exit(42);


  

  readStr = fetchBlock( (char *) "./test.bin",s,l);
  cout <<"Fetched: " << bin2hex(readStr ,l)<<endl;

  /* 
  ret = writeFile( (char *) "./test.bin",(unsigned char *) "\xAA\xCC\xBB\xBB\xAA\xAA\xBB\xBB\xAA\xAA\xBB\xBB", 12);
  cout <<"Wrote?: "<<ret<<endl; 

  readStr = fetchBlock( (char *) "./test.bin",s,l);
  cout <<"Fetched: " << bin2hex(readStr ,l)<<endl;
  */
  cout <<"----------------------------" <<endl;

  Cipher * c = new Cipher();
  char * plaintext = (char *)"\xDE\xAD\xBE\xEF\xDE\xAD\xBE\xEF\xDE\xAD\xBE\xEF\xDE\xAD\xBE\xEF\xDE\xAD\xBE\xEF\xDE\xAD\xBE\xEF\xDE\xAD\xBE\xEF\xDE\xAD\xBE\xEF";
  int len = 32;
  int outl, outl2;
  unsigned char * ciph, * pl;
  
  c->init("1234");

  cout<<"Plaintext:"<<bin2hex( (unsigned char*) plaintext,len)<<" ("<<len<<")"<<endl;

  ciph = c->encrypt( (unsigned char *) plaintext,len,&outl);

  cout<<"Encrypted (hex):"<<bin2hex(ciph,outl)<<" ("<<outl<<")"<<endl;

  pl = c->decrypt( ciph,outl,&outl2);

  cout<<"Decrypted:"<<bin2hex( (unsigned char*) pl,outl2)<<" ("<<outl2<<")"<<endl;

  cout <<"----------------------------" <<endl;
  

  unsigned char * hash;
  int outlen;

  string text1 = "holaquetal";
  hash = sha256digest((unsigned char*)text1.c_str(),text1.length(), &outlen);
  cout <<"Text: "<<text1<<endl;
  cout <<"digest: "<<bin2hex(hash,outlen)<<endl;

  string text2 = "holaquetal1";
  hash = sha256digest((unsigned char*)text2.c_str(),text2.length(), &outlen);
  cout <<"Text: "<<text2<<endl;
  cout <<"digest: "<<bin2hex(hash,outlen)<<endl;
  
  string text3 = "holaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetalholaquetal";
  hash = sha256digest((unsigned char*)text3.c_str(),text3.length(), &outlen);
  cout <<"Text: "<<text3<<endl;
  cout <<"digest: "<<bin2hex(hash,outlen)<<endl;
}



// echo -ne "\xFF\x00\xFF\x00\xDE\xAD\xBE\xEF\xFF\x00\xFF\x00" > test.bin
