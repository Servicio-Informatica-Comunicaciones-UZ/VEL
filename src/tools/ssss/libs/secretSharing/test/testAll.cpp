/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/

#include "../secretSharer.h"

#include <iostream>
#include <cstring>
#include <cstdlib>
#include <cstdio>


#include <openssl/sha.h>

#define TESTNUM 100000

#define SECRETMAXLEN (512*18)




using namespace std;



char * bin2hex(unsigned char *bin, int l)
{
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



int hazPrueba(  FILE * rnd ){
  
  int K;
  int N;
  
  int CHUNKLEN;   //Max 512
  int SECRETLEN;  //Max SECRETMAXLEN
  int secretPieceLen;

  char secret[SECRETMAXLEN];

  char blockBuffer[10224];
  
  int iter;
  
  secretSharer * ss;
  secretSharer * ss2;

  
  char * retrieved = NULL;
  int seclen;

  secretSharer::Share * shares;


  int err;

  int errstate = 0;
  int minlen  = 0;
  
  int tamTrozoInicial;

 
  
    
  errstate = 0;
  err = 0;
  

  ss = new secretSharer((char *)"holaquetal");
  
  
  //Cambiar K, N secretlen y chunklen
  K = 2 + (rand()%15);   //15;
  N = K + (rand()%10);   //21;
  
  cout<<"     K: "<<K<<endl;
  cout<<"     N: "<<N<<endl;
  
  
  //Limitamos el tamaño del chunk a entre 100 y 256 porque si no la generación del primo dispara el tiempo
    CHUNKLEN =  100 +(rand()%(256-100));  //159; 
    SECRETLEN = 1+ rand()%((CHUNKLEN*18)-1);     //2860; 
    
    cout<<" Chunk: "<<CHUNKLEN<<endl;
    cout<<"Secret: "<<SECRETLEN<<endl;
    
    secretPieceLen = CHUNKLEN;
    
    
    //Leemos un secreto aleatorio de long máxima
    do{ 
      //Leemos el primer caracter y nos aseguramos de que no sea \0
      fread(secret,sizeof(char),1,rnd);
    }while(!secret[0]);
    fread(secret+1,sizeof(char),SECRETLEN-1,rnd); 
    
    //cout<<"Secreto: "<<bin2hex((unsigned char *)secret,SECRETLEN)<<endl; 
    
    //cout<<"Sharing..."<<endl;
    err = ss->initSharing(K,N,CHUNKLEN);
    if(err){
      printf("Error %x initialising sharing\n",err);
      return 0; 
    }
    
    cout<<"Check2"<<endl;

    if((rand() % 5 ) < 3 ){ //Un 60% de las veces empezaremos con una cadena que no llene el buffer
      do{
        secretPieceLen = rand() % CHUNKLEN;
      }while(secretPieceLen==0);
    }else{
      do{
        secretPieceLen = rand() % SECRETLEN;
      }while(secretPieceLen==0);
    }
    
    tamTrozoInicial = secretPieceLen;
    //cout<<"Tam trozo inicial: "<<tamTrozoInicial<<endl;

          
    cout<<"Check3"<<endl;

    iter=0;
    while(iter<=SECRETLEN-secretPieceLen){
             
      err = ss->updateSecret(secret+iter, secretPieceLen);
        
      if(err == 0){
        cout<<"Error updating secret, no space?"<<endl;
        return 0;
      }
      
      //cout<<"Compartiendo ("<<iter<<":"<<iter+secretPieceLen-1<<"): "<<endl;
      //cout<<bin2hex((unsigned char *)secret+iter,secretPieceLen)<<endl;
      
      iter+=secretPieceLen;
      
      if(iter<SECRETLEN){
        if((rand() % 5 ) < 3 ){  //UN 60% DE LAS VECES elige UN TROZO ENTRE MEDIO Y UN CHUNK ENTERO
          do{
            secretPieceLen = CHUNKLEN/2 + (rand() % (CHUNKLEN/2));
            if(SECRETLEN - iter<=1){
              secretPieceLen = 1;
            }
          }while(secretPieceLen==0);
        }else{
            do{
              secretPieceLen = rand() % (SECRETLEN - iter);
              if(SECRETLEN - iter<=1){
                secretPieceLen = 1;
              }
            }while(secretPieceLen==0);
            
          }
            
        //cout<<"Tam del trozo: "<<secretPieceLen<<endl;
      }
    }
    if(SECRETLEN-iter){//Si el secreto tiene resto, lo compartimos también
      //cout<<"Compartiendo resto... ("<<iter<<":"<<iter+(SECRETLEN-iter)-1<<")"<<endl;
      if(!ss->updateSecret(secret+iter, SECRETLEN-iter)){
        cout<<"Error updating secret"<<endl;
        return 0;
      }
    }
    
    shares = ss->getShares();
    
    
    if(!shares){
      cout<<"Error, getting shares"<<endl;
      return 0;
    }

    //cout<<"///////////////////////// SHARES OBTENIDAS //////////////////////////////"<<endl;
    //ss->printShares(shares,N,0);
    //ss->printShare(&shares[9],1);
    
    //cout<<"Init Revealing..."<<endl;
    
    ss2 = new secretSharer((char *)"holaquetal");
    
    if(ss2->initRetrieval()){
      cout<<"Error initialising retrieval"<<endl;
      return 0;
    }
    
    for(int i=0;i<N;i++){
      //cout<<"Adding share "<<i<<endl;
      err = ss2->addShare(&shares[i]);
      if(err){
        cout<<"Error "<<err<<"  Adding share "<<i<<endl;
        return 0;
      }
      
    }
    
    //Pruebas varias
    
    //cout<<"Size Share: "<<sizeof(secretSharer::Share)<<endl;
    
    //cout<<"Checking Share..."<<endl;
    
    for(int i=0; i<N; i++){
      
      //Copiamos una share
      memcpy(blockBuffer,&shares[i],sizeof(secretSharer::Share));
      
      
      //Ponemos a 0 el trozo del hash
      for(int j=0; j<32;j++){
        blockBuffer[sizeof(secretSharer::Share)-32+j] = 0;
      }
      
      //Comprobamos el primer Int 
      if(blockBuffer[0] != 11)
        cout<<"Share "<<i<<": No coincide el primer byte fijo"<<endl;
      
      //Comprobamos el último char antes del hash
      if(((int) blockBuffer[sizeof(secretSharer::Share)-1-32]) !=20)
        cout<<"Share "<<i<<": No coincide el ultimo byte fijo"<<endl;
      
      
      //cout<<"Hash interno: "<<bin2hex(shares[i].digest, 20)<<endl;
      //cout<<"hash externo: "<<bin2hex(SHA1((const unsigned char *) blockBuffer, sizeof(secretSharer::Share),NULL),20)<<endl;
      if(memcmp(shares[i].digest, SHA1((const unsigned char *) blockBuffer, sizeof(secretSharer::Share),NULL), 20))
        cout<<"Share "<<i<<": No coinciden los hash"<<endl;
    }
    
    
    
   
    
    //cout<<"Revealing... "<<endl;
    retrieved = ss2->getSecret(&seclen);
    
    if(!retrieved){
      cout<<"Error obteniendo secreto"<<endl;
      return 0;
    }
      
    
    //cout<<"Len secreto in  : "<<SECRETLEN<<endl;
    //cout<<"Len secreto out : "<<seclen<<endl;
    
    //cout<<"Coinciden?... "<<endl;
    
    minlen = seclen;
    if(SECRETLEN!=seclen){
      cout<<"No coincide la long de entrada y salida del secreto"<<endl;
      errstate = 1;
      if(SECRETLEN<seclen)
        minlen = SECRETLEN;
    }
    
    if(memcmp(retrieved,secret,minlen)){
      cout<<"NO COINCIDEN"<<endl;
      errstate = 1;
    }else{
      //cout<<"COINCIDEN"<<endl;
    }

    
    if(errstate){
      cout<<"Size Share: "<<sizeof(secretSharer::Share)<<endl;
      cout<<"K: "<<K<<endl;
      cout<<"N: "<<N<<endl;
      cout<<" Chunk: "<<CHUNKLEN<<endl;
      cout<<"Secret Len antes  : "<<SECRETLEN<<endl;
      cout<<"Secret Len despues: "<<seclen<<endl;
      cout<<"Secreto antes  : "<<bin2hex((unsigned char *)secret,SECRETLEN)<<endl;
      cout<<"Secreto despues: "<<bin2hex((unsigned char *)retrieved,seclen)<<endl;
      //for(int g=0;g<=SECRETLEN;g++){
      //  if(secret[g] == 0)
      //    cout<<"secret["<<g<<"] es cero."<<endl;
      //}
      cout<<"Trozo inicial: "<<tamTrozoInicial<<endl;
      ss->printShares(shares,N,0);
    }


    munlock(retrieved,seclen);
    delete [] retrieved;
    delete ss;
    delete ss2;
}



int main(void){
  
  FILE * rnd;
   
  rnd = fopen("/dev/urandom","r");

  //srand((unsigned int) time(NULL));
  srand(1);

  for(int testnum=0; testnum<TESTNUM; testnum++){
    
    cout<<"Prueba "<<testnum<<endl;
    
    hazPrueba(rnd);
  }
  
  fclose(rnd);
  
  return 0;
}



//SEGUIR: mejorar los tests pasando trozos aleatorios, verificar los tests de nuevo. hacer alguna prueba más. mostrar muchas cosas primero para verificar a mano y luego automatizar las pruebas y hacer muchas.



//Implementar la prueba de fraude

//Probar a hacer fraude

//probar con una cadena




