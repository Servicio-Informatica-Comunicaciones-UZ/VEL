/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/



#ifndef SECRET_SHARING_H
#define SECRET_SHARING_H


#include <openssl/bn.h>
#include <openssl/crypto.h>
#include <openssl/rand.h>

#include <sys/mman.h>


//Exceptions


#define GREATER_THRESHOLD            1
#define BAD_THRESHOLD                2
#define BAD_NUMSHARES                3
#define WEAK_POINT                   4
#define NO_RNG_SEED                  5
#define DUPLICATED_POINT             6
#define SECRET_TOO_LONG              7
#define ERROR_CONVERTING_INDEX_TO_BN 8
#define BAD_SECRET_LEN               9
#define ERROR_GENERATING_COEFFS      10
#define ERROR_SETTING_BN             11
#define NOT_ENOUGH_SHARES            12
#define DUPLICATE_SHARES             13
#define BAD_X                        14
#define BAD_PRIME                    15
#define BAD_PRIME_SIZE               16


#include <iostream>
#include <cstring>

using namespace std;



//p k n i q(i)


typedef struct ShareSt{
  int i;
  unsigned char * qi;
  int qiLen;
} PlainShare;


typedef struct SecretSt{
  unsigned char * data;
  int len;
} Secret;



static void genPrimeDefaultCB(int code, int arg, void *cb_arg);


static void genPrimeDefaultCB(int code, int arg, void *cb_arg)
{
  if (code == 0)
    cerr<<endl<<"Found potential prime #"<<(arg + 1)<<" ...";
  else if (code == 1 && arg && !(arg % 10))
    cerr<<".";
  else
    cerr<<endl<<"Primality verified"<<endl;
}



static void (*genPrimeCB) (int,int,void*) = genPrimeDefaultCB; //Puntero a la funcion de callback

int setGenPrimeCB(void (*f) (int,int,void*));


class secretSharing
{
  
private:

  static const int INIT      = 1;
  static const int SECRETLEN = 2048/8; //Debe ser mult. de 8 


  static int seeded; //Indica si ya hemos alimentado el PRNG (la inicializamos a 0 fuera de la clase)

  int k;
  int n;

  int primeByteLen;     // secretByteLen+; Debe ser > 512/8  
  int secretByteLen;

  char ** indexes;
  
  BIGNUM * p;
  BIGNUM ** coeffs;  
  
  int seed_prng(int bytes);
  BIGNUM * generateBigPrime();
  
  
  int generateCoeffs();
  int destroyCoeffs();
  
  inline int init(int threshold, int numshares, int secretByteLength=SECRETLEN,  int initial=INIT);
  
  
public:

  
  //Genera el sistema de ecuaciones para poder compartir un secreto (índices secuenciales desde initial)
  secretSharing(int threshold, int numshares, int secretByteLength=SECRETLEN, int initial=INIT);  
  
  //Genera el sistema de ecuaciones para poder compartir un secreto (lleva un vector de índices a sustituir)
  secretSharing(int threshold, int numshares, int * idxs, int secretByteLength=SECRETLEN);  
  
  //Prepara el objeto para reconstruír un secreto compartido en otro objeto
  secretSharing(int threshold, unsigned char * prime, int primeByteLength);
  
  ~secretSharing(void);

  
  int getPrimeByteLen(void);
  int getSecretByteLen(void);

  //Por cortesía, devuelve números aleatorios (para no replicar código en clases superiores)
  unsigned char getRandByte(int allowZeroes=0);

  
  //Genera las piezas y las guarda (permite compartir múltiples secretos con la misma 'clave')
  PlainShare * share(Secret secretSt); 
  
  //Nos devuelve p, para reconstruir el secreto en el futuro con un nuevo objeto
  unsigned char * getPrime(int * len);
  
  //Reconstruye la clave, verificando además si las piezas sobrantes son parte de la clave también
  Secret * reveal(PlainShare * inShares, int len, int mlockSecret=1);
  
};


#endif //SECRET_SHARING_H
