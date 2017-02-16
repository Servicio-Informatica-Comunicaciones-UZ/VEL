/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/

#ifndef SECRET_SHARER_H
#define SECRET_SHARER_H

#include <iostream>
#include <cstdio>
#include <cstring>


#include <sys/mman.h>

#include <openssl/sha.h>

#include "secretSharing.h"

using namespace std;



//Secreto -->  lista de Shares


//Implementar aquí sistema de verificación de fraude (si tengo + de k elems, resolver el sistema con dos subconjuntos de k elems de n distintos cuya union sea n, y ver si dan el mismo resultado)  

//En las pruebas, intentar hacer fraude, a ver qué pasa (puede que se cuelgue)

//En las pruebas de compartición hacer todas las posibilidades (que los chunks del mensaje que le pasa sean de tam aleatorio, desde 1 byte hasta la long total del mensaje)


#define    SS_OK 0
#define    SS_BAD_THRESHOLD 2
#define    SS_BAD_NUMSHARES 3
#define    SS_GREATER_THRESHOLD 4
#define    SS_ERROR_INITIALIZING_SHARING 5
#define    SS_OUT_OF_MEMORY 6
#define    SS_ERROR_LOCKING_MEM 7
#define    SS_BAD_ID_LENGTH 8
#define    SS_HASH_CHECK_FAILED 9
#define    SS_NO_MATCHING_PRIME 10
#define    SS_NO_MATCHING_ID 11
#define    SS_NO_MATCHING_THRESHOLD 12 
#define    SS_ERROR_REALLOCATING_SHARE_ARRAY  13
#define    SS_NO_MATCHING_NUMSEGMENTS 14
#define    SS_NOT_ENOUGH_SHARES 15
#define    SS_ERROR_INITIALIZING_RETRIEVAL 16
#define    SS_BAD_MODE 17
#define    SS_NO_SHARE 18
#define    SS_BAD_CHUNKSIZE 19
#define    SS_UNEXPECTED_PAD_LENGTH 20
#define    SS_FAILURE_REVEALING_SEGMENT 21
#define    SS_NO_SHARES 22



class secretSharer
{
  
 private:
  
  /*
  enum ErrorCodes {
    SS_OK,
    SS_BAD_THRESHOLD,
    SS_BAD_NUMSHARES,
    SS_GREATER_THRESHOLD,
    SS_ERROR_INITIALIZING_SHARING,
    SS_OUT_OF_MEMORY,
    SS_ERROR_LOCKING_MEM,
    SS_BAD_ID_LENGTH,
    SS_HASH_CHECK_FAILED,
    SS_NO_MATCHING_PRIME,
    SS_NO_MATCHING_ID,
    SS_NO_MATCHING_THRESHOLD,
    SS_ERROR_REALLOCATING_SHARE_ARRAY,
    SS_NO_MATCHING_NUMSEGMENTS,
    SS_NOT_ENOUGH_SHARES,
    SS_ERROR_INITIALIZING_RETRIEVAL,
    SS_BAD_MODE,
    SS_NO_SHARE,
    SS_BAD_CHUNKSIZE,
    SS_UNEXPECTED_PAD_LENGTH,
    SS_FAILURE_REVEALING_SEGMENT,
    SS_NO_SHARES,
  };
  */
  static const int DEFAULTCHUNK   = 1024/8;           //siempre >512
  static const int CHUNKNUM       = 18;               //invariable
  static const int MAXIDLEN       = 128;              //invariable (y mult de 4)
  static const int MAXSEGMENTLEN  = 520;              //invariable (y mult de 4)
  static const int PADLEN         = 7;
  static const int MAXCHUNK       = MAXSEGMENTLEN - PADLEN; //Estos los usamos de padding para verificar 
  static const int RESERVED       = 15; 
  
  
  typedef struct SegmentST{
    unsigned char qi[MAXSEGMENTLEN];
    int i;
    int qiLen;
  }Segment;
  
  struct ShareBlockSt{
    int            idLen;
    unsigned char  id[MAXIDLEN];
    int            k;
    int            pLen;
    unsigned char  p[MAXSEGMENTLEN];
    int            pkcs1Padded;      //Indica que el último segment tiene padding pkcs1 (para evitar el caso de que el mensaje pareciese padding)
    int            padLen;      //Cuando el padding no es pkcs1, este indica cuánto hay que quitar
    int            nSegments;
    Segment        segments[CHUNKNUM];
    unsigned char  reserved[RESERVED];
    unsigned char  digestLen;   //Bytes que ocupa el hash
    unsigned char  digest[32];  //hash de todo el struct con el campo digest a cero  //Cabe hasta un sha256
    // 10224 bytes 


/*

En un principio, usaba 513 como MAXSEGMENTLEN y 96 bloques
reservados. En ese caso, había 18*3+6 bytes de diferencia entre la
suma de los bytes de los miembros y el sizeof del struct. Al parecer
se debe a que el compilador alinea los miembros a posiciones de mem
múltiplo de 4. Así pues, entre p y nSegments había 3 bytes
ocultos. entre qi e i de cada pos de segment, 3 bytes y 3 más entre
digestLen y digest.

Ahora lo he ampliado para que no existan huecos ocultos. Cada segmento tiene un tam mult de 4, y 
*/


    // hay 3 bytes luego digest no acaba en 10223, sino en 10220)

    //4+128+4+4+513+4+(18*(4+4+513))+96+1+32 = 10164
    //10224-10164 = 60
    
    //4+128+4+4+513+4+(18*(4+4+513 + 3  ))+96+1+32   +3  = 10221  (y los 3 que faltan de qué struct son el overhead?)
  };
  
  
  enum Modes  {INIT, SHARE, RETRIEVE};
  
  Modes mode;

 
  
  char * realSecretBuffer;  //Este apunta al inicio del buffer, donde pondremos el padding de tipo 1
  char * secretBuffer;      //Este apunta después del padding, al inicio de la zona de datos
  int    secretBufferLen;
  int    realSecretBufferLen;
  int    secBufNextPos;

  secretSharing * SS;
  
  int K;
  int N;
  
  char ID[128];
  int IDlen;

  char * prime;
  int primeLen;
  int segNum;
  
  int modeReset(void); //Si hay un cambio de modo, lo pone todo a cero, como si acabaramos de crear el objeto

  int flushSecretBuffer(void);

  char * bin2hex(unsigned char *bin, int l);
    

 public:

  typedef struct ShareBlockSt Share;

  
  //Si no se especifica IDlen, suponemos que es una cadena
  secretSharer(char * secretId, int IDlen=0);
  
  ~secretSharer();
  
  int getMaxIdLen() {return MAXIDLEN;};
  int getMaxChunkLen() {return MAXCHUNK;};
  int getMaxChunkNum() {return CHUNKNUM;};

  //hay 18 chuncks. El chunksize indica cuántos datos se guadarán en cada uno (entre 128 bytes (1024 bits) y MAXCHUNK bytes
  int initSharing(int threshold, int shareNum, int chunkSize=DEFAULTCHUNK);
  
  // Acumula trozos de secreto si estos son más cortos de un segment o genera varios si son mayores.
  //Devuelve 0 si hay error, o sino el num de bytes escritos en esta llamada.
  int updateSecret(char * secret, int len);
  
  Share * getShares(void);  //Finaliza la compartición (si queda algo menos de un segment, hace padding y lo comparte)y devuelve el array de shares //Internamente aplica padding a cada segmento, para verificar su reconstrucción luego

  void printShare(Share * share, int printAll=1);
  void printShares(Share ** shares, int len, int printAll=1);
  void printShares(Share * shares, int len, int printAll=1);

  void printInternalShares(int printAll=1);
  
  
  Share * copyShare(Share * share);

  
  int initRetrieval(void);
  
  int addShare(Share * share);

  char * getSecret(int * len=NULL);  ///Si len es NULL, suponemos que el secreto era una cadena
  

 private:
  
  Share ** inShares;
  int             inSharesLen;
  
  Share * outShares;
  int            outSharesLen;

};




#endif //SECRET_SHARER_H
