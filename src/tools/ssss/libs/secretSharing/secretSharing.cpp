/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/


#include "secretSharing.h"



//Inicializo aquí los miembros estáticos porque si lo hago en el .h, al incluirlo en el programa el linker lo considera redefinido.
int secretSharing::seeded = 0;


int secretSharing::seed_prng(int bytes)
{
  if (!RAND_load_file("/dev/urandom", bytes))   // OJO, fuente no entrópica!!!!!!!!
    return 0;
  return 1;
}


unsigned char secretSharing::getRandByte(int allowZeroes)
{
  unsigned char buff = 0;
  
  do{
    RAND_bytes(&buff,1);
  }while(!allowZeroes && !buff);
  
  return buff;
}



int setGenPrimeCB(void (* f) (int,int,void*)){
  genPrimeCB=  f;
}



BIGNUM * secretSharing::generateBigPrime()
{
  BIGNUM * bn;
  //cerr<<"Generating prime "<<endl;
  bn = BN_generate_prime(NULL, primeByteLen*8, 0, 0, 0, genPrimeCB, 0); 
  //cerr<<"----->Prime: "<<BN_bn2hex(bn)<<endl;
  return bn; 
}


int secretSharing::generateCoeffs()
{
  
  unsigned char buff[secretByteLen];
  
  
  coeffs = new BIGNUM * [k];
  
  
  //Generamos un BN vacio para el term indep
  coeffs[0] = BN_new();
  
  //Generamos todos los coeffs menos el termino indep
  for(int i=1; i<k; i++){
    
    do{
      
      if(RAND_bytes(buff,secretByteLen)){
        coeffs[i] = BN_bin2bn(buff, secretByteLen, NULL);
        //cerr<<"Coeffs["<<i<<"]: "<<BN_bn2dec(coeffs[i])<<endl;  //Quitar
      }
      else{
        throw  ERROR_GENERATING_COEFFS;
        return 0;
      }
    }while(BN_is_zero(coeffs[i]));
  }
  return 1;
}


int secretSharing:: destroyCoeffs()
{
  for(int i=0; i<k; i++){
    BN_free(coeffs[i]);    
  }
  delete [] coeffs;

  return 1;
}

int secretSharing::init(int threshold, int numshares, int secretByteLength, int initial)
{
  
  char idxbuff[15];
  
 
  if(threshold < 2){
    throw BAD_THRESHOLD;
    return 0;
  }

  if(numshares < 2){
    throw BAD_NUMSHARES;
    return 0;
  }
  
  if(threshold > numshares){
    throw GREATER_THRESHOLD;
    return 0;
  }

  if(initial < INIT){
    throw WEAK_POINT;
    return 0;
  }

  if(secretByteLength < (512/8)){
    cerr<<"Len: "<<secretByteLength<<endl;
    throw BAD_PRIME_SIZE;
  }
  
  primeByteLen  = secretByteLength+1;
  
  secretByteLen = secretByteLength;


  //Alimentamos el PRNG (sólo 1 vez por ejecución del programa, no una para cada objeto)
  if(!seeded){
    //cerr<<"Seeding the PRNG..."<<endl;
    if(!seed_prng(16)){   //Ojo, sólo coge entropía del ratón.
      throw NO_RNG_SEED;
      return 0;
    }
    seeded = 1;
  }
  
  k            = threshold;
  n            = numshares;
  
  indexes = new char * [numshares];
  
  for(int i=0; i< numshares; i++){

    snprintf(idxbuff,14,"%d",initial+i);

    indexes[i] = new char[strlen(idxbuff)];
    
    strcpy(indexes[i],idxbuff);
  }
  

  
  p = generateBigPrime();

}



secretSharing::secretSharing(int threshold, int numshares, int secretByteLength, int initial)
{
  
  init(threshold,numshares,secretByteLength,initial);
  
} 



secretSharing::secretSharing(int threshold, int numshares, int * idxs, int secretByteLength)
{
  char idxbuff[15];
  
  
  init(threshold,numshares,secretByteLength);
  
  
  for(int i=0; i< numshares; i++){ 

    if(idxs[i] == 0){
      throw WEAK_POINT;
      return;
    }
    
    for(int j=0; j< numshares; j++){
      if(i!=j && idxs[i] == idxs[j]){
        throw DUPLICATED_POINT;
        return;
      }
    }
  }
  

  for(int i=0; i< numshares; i++){
    
    snprintf(idxbuff,14,"%d",idxs[i]);
    
    delete [] indexes[i];
    
    indexes[i] = new char[strlen(idxbuff)];
    
    strcpy(indexes[i],idxbuff);
  }
  
  //cerr<<"p:"<<BN_bn2dec(this->p)<<endl;
  
}



//Este es para cuando generamos el objeto con el objetivo de reconstruir un secreto compartido en otro objeto
secretSharing::secretSharing(int threshold, unsigned char * prime, int primeByteLength)
{
  
  indexes = NULL;
  n = 0;
  
  if(threshold < 2){
    throw BAD_THRESHOLD;
  }
  
  k = threshold;
  
  if(primeByteLength <= (512/8)){
    cerr<<"Len: "<<primeByteLength<<endl;
    throw BAD_PRIME_SIZE;
  }
  
  primeByteLen  = primeByteLength;
  
  secretByteLen = primeByteLength-1;
  
  
  p = NULL;
  p = BN_bin2bn((const unsigned char *)prime,primeByteLen, NULL);
  
  if(!p){
    throw BAD_PRIME;
  }
  
  
}




secretSharing::~secretSharing(void)
{
  BN_free(p);
  
  for(int i=0; i<n; i++)
    delete [] indexes[i];
  
  
  if(indexes)
    delete [] indexes;
}  


int secretSharing::getPrimeByteLen(void)
{
  return primeByteLen;
}


int secretSharing::getSecretByteLen(void)
{
  return secretByteLen;
}

    

//Cuando todo funcione, en vez de reservar k BIGNUMS para b, reservar sólo 2 y poner los índices en %2

PlainShare * secretSharing::share(Secret secretSt)
{

  PlainShare  * shares;
  BIGNUM * idx = BN_new();
  BIGNUM ** b = new BIGNUM * [2];  //Con 2 nos basta
  BIGNUM * y; //Alias para b[0], que es el valor de sustituir el polinomio
  BN_CTX * stat = BN_CTX_new();
  
  
  //Alias
  int secretLen = secretSt.len;
  unsigned char * secret = secretSt.data; 
  
 
  b[0] = BN_new();
  b[1] = BN_new();


  
  
  if(secretLen<=0){
    throw BAD_SECRET_LEN;
    return 0;
  }
  
  if(secretLen>secretByteLen){
    throw SECRET_TOO_LONG;
    return 0;
  }

  

  shares = new PlainShare [n];
    
    
  //Regeneramos el polinomio para cada secreto que compartimos
  generateCoeffs();

  
  //for(int i=0; i<k; i++){
  //  cerr<<"coeff "<<i<<": "<<BN_bn2dec(coeffs[i])<<endl<<endl;
  //}
  

  //Pasamos el secreto a BN y lo escribimos en coeffs[0]
  BN_bin2bn(secret, secretLen, coeffs[0]);


  //Para cada pieza a crear (por cada sustitucion del polinomio)
  for(int i=0; i<n; i++) {
    
    
    
  
    if(!BN_dec2bn(&idx, indexes[i] )){  //Escribimos el idx como un BN
      throw ERROR_CONVERTING_INDEX_TO_BN;
      return 0;
    }
    
    //cerr<<"----> Idx: "<<BN_bn2dec(idx)<<endl;



    // *** Evaluación de polinomios de horner ***
    
    //b[k-1] = coeffs[k-1];
    BN_copy(b[(k-1)%2],coeffs[k-1]);
    

    for(int j=k-2;  j>=0;  j--){
      
      // ---> b[j] = coeffs[j] + b[j+1] * idx   % p;
      
      
      //-> b[j] =  b[j+1]*idx %p
      BN_mod_mul(b[(j)%2],b[(j+1)%2],idx,p,stat);

      //-> b[j] = b[j] + coeffs[j] %p
      BN_mod_add(b[(j)%2],b[(j)%2],coeffs[(j)%2],p,stat);
      
    }

    y = b[0];
    
    
    //Escribimos y como Share

    shares[i].i     = atoi(indexes[i]);
    shares[i].qiLen = BN_num_bytes(y);
    shares[i].qi    = new unsigned char [shares[i].qiLen];
    
    shares[i].qiLen = BN_bn2bin(y, shares[i].qi);


    

  } //Fin 'para cada pieza'
  
/*
  cerr<<"PIEZAS GENERADAS:"<<endl;
  
  for(int i=0; i<n; i++) {
    cerr<<"------ Pieza "<<shares[i].i<<" ------"<<endl;
    BN_bin2bn(shares[i].qi,shares[i].qiLen,idx);
    cerr<<BN_bn2hex(idx)<<endl;
    cerr<<"---------------------"<<endl;
    
  }
*/

  destroyCoeffs();

  BN_free(idx);

  BN_free(b[0]);
  BN_free(b[1]);

  delete [] b;

  BN_CTX_free(stat);


  return shares;

}



unsigned char * secretSharing::getPrime(int * len)
{

  int plen;
  unsigned char * retbuf;
  
  //cerr<<"P: "<<BN_bn2hex(p)<<endl;
  
  //cerr<<"P: "<<BN_bn2dec(p)<<endl;
  
  plen = BN_num_bytes(p);
  
  retbuf = new unsigned char [plen];
  
  plen = BN_bn2bin(p, retbuf);  

  * len = plen;

  return retbuf;
}



Secret * secretSharing::reveal(PlainShare * inShares, int len, int mlockSecret)
{

  char auxstr[15];

  BIGNUM * L    = BN_new(); 
  BIGNUM * l_i  = BN_new();
  BIGNUM * x    = BN_new();
  BIGNUM * x_i  = BN_new();
  BIGNUM * x_j  = BN_new();
  BIGNUM * aux  = BN_new();
  BIGNUM * aux2 = BN_new();
  BN_CTX * stat = BN_CTX_new();
    

  Secret *  retval = new Secret;


  //Comprobar que hay al menos k shares
  if(len <k){
    throw NOT_ENOUGH_SHARES;
  }
  
  //Comprobar que sean todas las shares  distintas y las x!=0
  for(int i=0; i<len;i++){
    
    if(inShares[i].i<=0)
      throw BAD_X;
    
    for(int j=0; j<len;j++)
      if(i!=j && !memcmp(inShares[i].qi, inShares[j].qi, inShares[i].qiLen)) //Si hay 2 iguales
        throw DUPLICATE_SHARES;
  }
  
  // --= Polinomio interpolador de Lagrange =--

  
  //Ponemos a cero el valor de la x a interpolar, para que el resultado sea el term indep (se revele el secreto)
  //Sería más eficiente si no contemplase este parámetro, porque es cero, pero así lo tengo preparado para comprobar otros puntos
  if(!BN_zero(x)){
    throw ERROR_SETTING_BN;
  }
  
  //Ponemos a cero el resultado, para iniciar el sumatorio
  if(!BN_zero(L)){
    throw ERROR_SETTING_BN;
  }
  
  //Por cada punto a interpolar
  for (int i = 0; i < k; i++) { 
    
    
    sprintf(auxstr,"%d",inShares[i].i);
    BN_dec2bn(&x_i,auxstr);
    
    //cerr<<"x_i: "<<BN_bn2dec(x_i)<<endl;
    
    
    //Ponemos el valor del polinomio base a 1, para iniciar el productorio
    if(!BN_one(l_i)){
      throw ERROR_SETTING_BN;
    }
    
    //Por cada punto a interpolar
    for (int j = 0; j < k; j++) {
  
      //distinto de sí mismo
      if (j != i) {
        
        sprintf(auxstr,"%d",inShares[j].i);
        BN_dec2bn(&x_j,auxstr);

        //cerr<<"x_j: "<<BN_bn2dec(x_j)<<endl;

        
        //l_i *= (x - pos[j]) / (pos[i] - pos[j]);
        BN_mod_sub(aux,  x, x_j, p, stat);
        
        BN_mod_sub(aux2, x_i, x_j, p, stat);


        BN_mod_inverse(aux2, aux2, p, stat);
        
        
        BN_mod_mul(aux, aux, aux2, p, stat);
        
        BN_mod_mul(l_i, l_i, aux, p, stat);
        
      }
    }

    //L += l_i * val[i]; 

    //Escribimos en aux la y_i

    BN_bin2bn(inShares[i].qi, inShares[i].qiLen, aux);

    BN_mod_mul(l_i, l_i, aux, p, stat);
    
    BN_mod_add(L,L,l_i,p,stat);
    
   } 

  //cerr<<"EL secreto en hex: "<<BN_bn2hex(L)<<endl;
  
  
  retval->len = BN_num_bytes(L);

  //cerr<<"Numbytes antes: "<<retval->len<<endl;

  retval->data = new unsigned char [retval->len];

  if(mlockSecret){
    mlock(retval->data,retval->len);
  }


  retval->len = BN_bn2bin(L, retval->data);

  //cerr<<"Numbytes despues: "<<retval->len<<endl;

  return retval; 

}


//   ****** Sustituir el sistema para cada share, incluso si sobran y devolver error si hay puntos que no son solución
