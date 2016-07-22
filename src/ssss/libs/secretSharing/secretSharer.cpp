/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/


#include "secretSharer.h"






/*

El id de secreto se mantiene hasta la destrucción del objeto. ¿Por
qué?, porque en vez de crear un 'servidor' de compartición de
secretos, hacemos que un secreto pueda ser compartido y reconstruído
por el mismo objeto, o por dos distintos, o que un secreto cambie de
contenido (porque se reinicia el proceso); pero no que un mismo objeto
permita compartir distintos secretos (cambiar el id de
Secreto). Podría hacerse facilmente, pero:

     1.- Puede confundir al usuario.

     2.- Resulta más seguro obligar a generar un primo distinto para
     cada secreto.

*/


secretSharer::secretSharer(char * secretId, int IDlength)
{    
  
  if(IDlength < 0 || IDlength > 128){
    throw SS_BAD_ID_LENGTH;
  }
  
  if(IDlength == 0){
    IDlen = strnlen(secretId,MAXIDLEN)+1;
    
    if(IDlen>=128)  //La len era >=128
      throw SS_BAD_ID_LENGTH;  //Si es una cadena puede tener como mucho 127
  }
  else{
    IDlen = IDlength;
  }
  

  

  memcpy(ID,secretId, IDlen);

  mode = INIT;
  
  inShares = NULL;
  inSharesLen = 0;
  
  outShares = NULL;
  outSharesLen = 0;
  
  realSecretBuffer    = NULL;  
  realSecretBufferLen = 0;
  secretBuffer    = NULL;
  secretBufferLen = 0;
  
  SS = NULL;

  prime = NULL;
  primeLen = 0;
  segNum = 0;



  modeReset();
}










secretSharer::~secretSharer()
{
  modeReset();  
}

 





 
int secretSharer::modeReset(void)
{
  
  if(inShares != NULL){
    for(int i=0; i<inSharesLen; i++)
      delete inShares[i];
    free(inShares);
  }
  
  if(outShares != NULL)
    delete [] outShares;
  
  if(realSecretBuffer != NULL){
    memset(realSecretBuffer,0,realSecretBufferLen);
    munlock(realSecretBuffer, realSecretBufferLen);
    delete [] realSecretBuffer;
  }

  if(SS != NULL)
    delete SS;
  
  SS = NULL;
  
  if(prime !=NULL)
    delete prime;

  mode = INIT;
  
  inShares = NULL;
  inSharesLen = 0;
  
  outShares = NULL;
  outSharesLen = 0;
  
  realSecretBuffer    = NULL;  
  realSecretBufferLen = 0;
  secretBuffer    = NULL;
  secretBufferLen = 0; 
  secBufNextPos   = 0;
  
  
  K = 0;
  N = 0;
    
  prime = NULL;
  primeLen = 0;
  segNum = 0;

  return 0;
}








//Coge el contenido del buffer de secreto y lo vuelca a la sig pos de segmento libre para cada item de la estructura de shares
int secretSharer::flushSecretBuffer(void){

  PlainShare * partShares = NULL;
  Secret sec;
  int currentSegment = 0;
 
  if(mode != SHARE)
    return SS_BAD_MODE;

  currentSegment = outShares[0].nSegments;

  if(currentSegment >= CHUNKNUM){
    //No quedan Segmentos libres, secreto demasiado largo
    return 0;
  }


  //Hacemos el pkcs1 type 1 pad  que nos permitirá verificar luego la correcta reconstrucción
  //Ya se que cabe la posibilidad de que un mensaje mal reconstruido
  //empiece por este patrón, y que 7 bytes es poco para que esa
  //probabilidad sea lo bastante baja, pero es lo que hay. No me queda
  //más espacio
  realSecretBuffer[0] = 0;
  realSecretBuffer[1] = 1;
  
  realSecretBuffer[PADLEN-1] = 0;
  
  for(int i=2; i<PADLEN-1;i++)
    realSecretBuffer[i] = 0xFF;
  
  

  //Ver el bloque con padding tipo 1
  
  //cerr<<"mensaje con padding de verificacion: ";
  //for(int j=0; j<realSecretBufferLen; j++)
  //  cerr<<bin2hex((unsigned char *) &realSecretBuffer[j],1);
  //cerr<<endl;
  //cerr<<"Longitud mensaje: "<<secretBufferLen<<endl;
  


  
  sec.len    = realSecretBufferLen;
  sec.data   =  (unsigned char *) realSecretBuffer;
  
  partShares = SS->share(sec);
  
  for(int i=0; i<N; i++){
    outShares[i].segments[currentSegment].i     = partShares[i].i;
    outShares[i].segments[currentSegment].qiLen = partShares[i].qiLen;
    
    memcpy(outShares[i].segments[currentSegment].qi, partShares[i].qi, partShares[i].qiLen);
    
    outShares[i].nSegments++;
  }
  
  for(int i=0; i<N; i++){
    delete [] partShares[i].qi;
  }
  delete [] partShares;
  
  //cerr<<"Written segment "<<currentSegment<<endl;
  
  return 1;
}













int secretSharer::initSharing(int threshold, int shareNum, int chunkSize)
{    

  if(threshold < 2){
    return SS_BAD_THRESHOLD;
  }
  
  if(shareNum < 2){
    return SS_BAD_NUMSHARES;
  }
  
  if(threshold > shareNum){
    return SS_GREATER_THRESHOLD;
  }
  
  //64 es 512 bits, que es el mínimo seguro para el tam de un secreto
  if(chunkSize < 64 || chunkSize > MAXCHUNK-1){
    return SS_BAD_CHUNKSIZE;
  }
  
  
  modeReset();  //Reseteamos el objeto para cambiar de modo
  
  
  K = threshold;
  
  N = shareNum;
  
  secretBufferLen = chunkSize;
  
  realSecretBufferLen = secretBufferLen+PADLEN; //Padding
  
  mode = SHARE;


  //Reservamos el vector que contendrá todas las shares
  try{
    outShares = new Share [shareNum];
  }catch(int e){ return SS_OUT_OF_MEMORY;}


  //Reseteamos el contador de segmentos de secreto a 0 
  //Ponemos a cero toda la estructura (por limpieza, para el digest)
  /*
  for (int i=0; i<shareNum; i++){
    outShares[i].idLen = 0;
    for(int j=0; j<MAXIDLEN; j++)
      outShares[i].id[j] = 0;
    outShares[i].k = 0;
    outShares[i].pLen = 0;
    for(int j=0; j<MAXSEGMENTLEN; j++)
      outShares[i].p[j] = 0;
    outShares[i].nSegments = 0;
    for(int j=0; j<CHUNKNUM; j++){
      outShares[i].segments[j].i     = 0;
      outShares[i].segments[j].qiLen = 0;
      for(int l=0; l<MAXSEGMENTLEN; l++)
        outShares[i].segments[j].qi[l] = 0;
    }
    for(int j=0; j<RESERVED; j++)
      outShares[i].reserved[j] = 0;
    outShares[i].digestLen = 0;
    for(int j=0; j<32; j++)
    outShares[i].digest[j] = 0;
  }
  */ 
  for (int i=0; i<shareNum; i++){
    memset(&outShares[i],0,sizeof(Share));
  }
    



  //Instanciamos el objeto secretsharing
  try{

    //Para debugging dejamos el default, porque tira por el terminal.
    setGenPrimeCB(NULL);               //Para producción. No saca nada. Descomentar
    
    SS = new secretSharing(K,N,realSecretBufferLen);
  }
  catch(int e){ return SS_ERROR_INITIALIZING_SHARING;}
  
  
  //Reservamos el buffer del secreto y le hacemos un mlock
  realSecretBuffer = new char [realSecretBufferLen];
  secretBuffer = realSecretBuffer+PADLEN; //secretBuffer apunta después de donde va el padding
  
  if (mlock(realSecretBuffer, realSecretBufferLen)!=0){  //bloqueamos el buffer
    return SS_ERROR_LOCKING_MEM;
  }
  
  return 0;
}













int secretSharer::updateSecret(char * secret, int len){
  
  
  //Revisar todos los límites y comparadores

  int startPoint = 0;
  int i = 0;
  
  //cerr<<"--------------Llamada a updatesecret"<<endl;
  //cerr<<"len: "<<len<<endl;
  //cerr<<"secbuflen: "<<secretBufferLen<<endl;

  if(mode != SHARE)
    return SS_BAD_MODE;
  
  //Si en todo el secreto no hay suficiente para llenar el buffer, lo escribimos y salimos
  if(len < secretBufferLen-secBufNextPos){
    
    //cerr<<":::::::No llena el buffer: nextPos: "<<secBufNextPos+len<<endl;
    
    
    //Lo copiamos todo en el buffer
    memcpy(secretBuffer+secBufNextPos,secret,len);
    
    
    //Actualizamos el puntero secBufNextPos
    secBufNextPos += len;
    
    return len;
  }
  
  
  //Si hay suficiente pero teníamos algo en el buffer, lo acabamos de llenar y lo procesamos, antes que nada
  if(secBufNextPos!=0){
    
    //cerr<<":::::::Teniamos algo en el buffer: nextPos: "<<secBufNextPos<<endl;
    
    
    //Si hay exactamente lo necesario o mas, llenamos el buffer
    memcpy(secretBuffer+secBufNextPos,secret,secretBufferLen-secBufNextPos);
    
    //Startpoint+= el num de elems copiados, así si desborda, no entra en el bucle
    startPoint += secretBufferLen-secBufNextPos;
    
    //Ponemos a 0 el puntero secBufNextPos
    secBufNextPos = 0;
    
    //Procesamos el buffer
    if(!flushSecretBuffer()){
      //Devuelve 0 para indicar error (no queda espacio en el bloque)
      return 0;
    }
  
    
  }

  //cerr<<"StartPoint: "<<startPoint<<endl;

  
  //Por cada buffer entero que pueda llenarse  
  //Llegados a este punto, secBufNextPos SIEMPRE debe valer 0.
  for(i = startPoint; i <= (len-secretBufferLen); i+=secretBufferLen){
    
    //cerr<<":::::::procesamos un bloque completo"<<endl;


    //Llenamos el buffer
    memcpy(secretBuffer,secret+i,secretBufferLen);
    
    //Procesamos el buffer
    if(!flushSecretBuffer()){
      //Devuelve 0 para indicar error (no queda espacio en el bloque)
      return 0;
    }
  }
  
  
  //cerr<<"i a la salida: "<<i<<endl;

  //Si queda resto, lo dejamos en el buffer y lo marcamos con el puntero al fin
  //Restamos startPoint porque si hemos completado un buffer al empezar, este trozo debe quedar fuera del cómputo del 'resto' del bucle
  //Si no es cero, es que Desde el pto en que nos hemos quedado al rellenar el primer buffer q estaba a medias hasta el final, no se puede dividir exáctamente en secretBufferLen trozos , luego queda un resto
  //Esta vale: (len-startPoint)%secretBufferLen, pero es más cómodo hacer len -i

  //Si queda algo por procesar, lo escribimos en el buffer y lo dejamos para otro momento
  if(len - i){
    
    //cerr<<":::::::escribimos el resto y lo dejamos: quedan "<<len-i<<endl;
    
    //Copiar lo que falta desde i, len-i
    memcpy(secretBuffer,secret+i, len-i);
    
    //Poner el puntero para indicar cuánto tenemos
    secBufNextPos = len-i;
  }
  else{
    secBufNextPos = 0;
  }
  //cerr<<":::::::Llegamos al final. ret: "<<len<<endl;
  
  
  return len;
}














secretSharer::Share * secretSharer::getShares(void){


  int newStartPos = 0;
  char * P;
  int plen = 0;
  unsigned char tempDigest[SHA_DIGEST_LENGTH];
  Share * retval;
  int pkcs1Padded = 0;
  int padLen = 0;
  

  if(mode != SHARE)
    //SS_BAD_MODE
    return 0;

  //Si queda secreto en el buffer  lo procesamos
  if(secBufNextPos!=0){
    
    //cerr<<":::::::habia restos en el buffer "<<secBufNextPos<<endl;
    /*
    cerr<<"restos: ";
    for(int j=0; j<secBufNextPos; j++)
      cerr<<bin2hex((unsigned char *) &secretBuffer[j],1);
    cerr<<endl;
    */


    newStartPos = secretBufferLen - secBufNextPos;
    
    //Escribimos los datos presentes en el bloque al final del mismo (memmove es por si las zonas de mem se solapan)
    //Supongo que reservará un buff temporal, y si este no está locked?
    memmove(secretBuffer+newStartPos ,secretBuffer, secBufNextPos);
        
    
    //si hay un espacio razonable para el padding, aplicamos padding pkcs1 tipo 2 hasta llenar el bloque y
    if((secretBufferLen - secBufNextPos) >= 11){
      
    
      //Hacemos el pkcs1 type 2 pad (este es de type 2 para hacerlo
      //criptograficamente más resistente. Si el resto fuese de 1 byte,
      //el mensaje seria predecible y daria lugar a ataques por
      //diccionario, aunque no es excesivamente grave, porque cada
      //segmento de secreto está compartido con un polinomio distinto )
      
      secretBuffer[0] = 0;
      secretBuffer[1] = 2;
      
      secretBuffer[newStartPos-1] = 0;
      
      for(int i=2; i<newStartPos-1;i++)
        secretBuffer[i] = SS->getRandByte();
      
      /*
        cerr<<"mensaje con padding: ";
        for(int j=0; j<secretBufferLen; j++)
        cerr<<bin2hex((unsigned char *) &secretBuffer[j],1);
        cerr<<endl;
      */
      
      //Marcamos que el último segment tiene padding
      pkcs1Padded = 1;
      padLen      = newStartPos;
    }
    else{ //Si no cabe un padding de tipo 2, sólo ponemos a cero los primeros bytes no ocupados
      for(int i=0;i<newStartPos;i++){
        secretBuffer[i] = 0;
      }
      padLen      = newStartPos;
    }
    
    //Procesamos el último bloque, con padding o sin él
    if(!flushSecretBuffer()){
      //Devuelve 0 para indicar error (no quedan segments libres)
      return 0;
    }
    
  }

  P = (char *) SS->getPrime(&plen);
  
  
  memset(tempDigest,0,SHA_DIGEST_LENGTH);

  //Completamos los campos de cada Share
  for(int i=0; i<N; i++){
    
    outShares[i].idLen = IDlen;  
    memcpy(outShares[i].id,ID, IDlen);
    
    outShares[i].k = K;

    outShares[i].pkcs1Padded = pkcs1Padded;
    
    outShares[i].padLen = padLen;

    outShares[i].pLen = plen;
    memcpy(outShares[i].p, P, plen);
    
    
    outShares[i].digestLen = SHA_DIGEST_LENGTH; //20 bytes


    //Sacamos el digest de toda la estructura con el campo de digest a cero
    SHA1((const unsigned char *) &outShares[i] ,
         sizeof(Share),
         (unsigned char *) tempDigest);
    
    //cerr<<"HASH:              "<<bin2hex(tempDigest,20)<<endl;

    memcpy(outShares[i].digest,tempDigest,SHA_DIGEST_LENGTH);
  }
  
  //Devolvemos el array de Shares y ponemos outshares a NULL para que no lo destruya al hacer el cambio de modo
  retval = outShares;
  outShares = NULL;
  
  return retval;
  
}















char * secretSharer::bin2hex(unsigned char *bin, int l)
{
  unsigned char * ret;
  char digitos[] = "0123456789ABCDEF";

  ret = (unsigned char *) malloc ((l*2+1)*sizeof(char));

  for (unsigned char i = 0; i < l; i++) {
    ret[2*i]=  digitos[bin[i] >> 4];
    ret[2*i+1]=digitos[bin[i] & 0xf];
  }
  ret[2*l]= 0;

  return (char *) ret;
}














void secretSharer::printShare(Share * share, int printAll)
{
  int diglen = 0;


  cerr<<"idLen: "<<share->idLen<<endl;
  cerr<<"id: ";
  for(int j=0; j<getMaxIdLen(); j++)
    cerr<<bin2hex(&share->id[j],1);
  cerr<<endl;
  cerr<<"k: "<<share->k<<endl;
  cerr<<"pLen: "<<share->pLen<<endl;
  
  cerr<<"p (hex):";
  for(int j=0; j<getMaxChunkLen(); j++)
    cerr<<bin2hex(&share->p[j],1);
  cerr<<endl;
  cerr<<"pkcs1Padded: "<<share->pkcs1Padded<<endl;
  cerr<<"padLen: "<<share->padLen<<endl;
  cerr<<"nSegments: "<<share->nSegments<<endl;
  for(int j=0; j<getMaxChunkNum(); j++){
    if(printAll || share->segments[j].qiLen > 0){
      cerr<<"i: "<<share->segments[j].i    <<endl;
      cerr<<"qiLen: "<<share->segments[j].qiLen<<endl;
      cerr<<"qi: ";
      for(int l=0; l<getMaxChunkLen(); l++)
        cerr<<bin2hex(&share->segments[j].qi[l],1);
      cerr<<endl;
    }
  }
  cerr<<"RESERVED: ";
  for(int j=0; j<RESERVED; j++)
    cerr<<bin2hex((unsigned char *)&share->reserved[j],1);
  cerr<<endl;
  diglen = (int) share->digestLen;
  cerr<<"digestLen: "<<diglen<<endl;
  cerr<<"digest: ";
  for(int j=0; j<32; j++)
    cerr<<bin2hex(&share->digest[j],1);
  cerr<<endl;


}






void secretSharer::printInternalShares(int printAll)
{
  if(inShares != NULL)
    for (int i=0; i<N; i++){
      cerr<<"---------------- Share "<<i<<" ------------------"<<endl;
      printShare(inShares[i], printAll);
      cerr<<"-------------------------------------------"<<endl<<endl;
    }
  else if(outShares !=NULL)
    for (int i=0; i<N; i++){
      cerr<<"---------------- Share "<<i<<" ------------------"<<endl;
      printShare(&outShares[i], printAll);
      cerr<<"-------------------------------------------"<<endl<<endl;
    }
}







void secretSharer::printShares(Share ** shares, int len, int printAll)
{
  for (int i=0; i<len; i++){
    cerr<<"---------------- Share "<<i<<" ------------------"<<endl;
    printShare(shares[i], printAll);
    cerr<<"-------------------------------------------"<<endl<<endl;
  }
}










void secretSharer::printShares(Share * shares, int len, int printAll)
{
  for (int i=0; i<len; i++){
    cerr<<"---------------- Share "<<i<<" ------------------"<<endl;
    printShare(&shares[i], printAll);
    cerr<<"-------------------------------------------"<<endl<<endl;
  }
}









secretSharer::Share * secretSharer::copyShare(Share * share)
{
  Share * copySh = NULL;
  
  copySh = new Share;
  
  copySh->idLen = share->idLen;
  memcpy(copySh->id, share->id, MAXIDLEN); 

  copySh->k = share->k;
  
  copySh->pLen = share->pLen;
  memcpy(copySh->p, share->p, MAXSEGMENTLEN);
  
  copySh->pkcs1Padded = share->pkcs1Padded;

  copySh->padLen = share->padLen;

  copySh->nSegments = share->nSegments;
  
  for(int j=0; j<CHUNKNUM; j++){
    copySh->segments[j].i     = share->segments[j].i;
    copySh->segments[j].qiLen = share->segments[j].qiLen;
    
    memcpy(copySh->segments[j].qi,share->segments[j].qi,MAXSEGMENTLEN);
  }
  
  for(int j=0; j<RESERVED; j++)
    copySh->reserved[j] = share->reserved[j];
  
  copySh->digestLen = share->digestLen;
  memcpy(copySh->digest, share->digest, 32);
  
  
  return copySh;
}

  
  








int secretSharer::initRetrieval(void)
{
  modeReset();  //Reseteamos el objeto para cambiar de modo
  
  mode = RETRIEVE;
  
  
  inSharesLen = 8;  //La longitud actual del vector (cuántos hay disponibles), puede crecer, inicio arbitrario
  

  //Usamos malloc, que es menos eficiente, para poder usar luego realloc
  inShares = (Share **) malloc(inSharesLen*sizeof(Share *));
  
  for(int i=0; i<inSharesLen; i++)
    inShares[i] = new Share;

  
  secretBuffer    = NULL;
  secretBufferLen = 0;   //Esto es la long real del buffer
  secBufNextPos   = 0;  

  SS = NULL;  //Instanciar cuando tenga los datos necesarios
  
  K = 0;   //El grado del pol. verificar cada uno que entre
  N = 0;   //El número de shares que realmente hay
  
  for(int i=0; i<MAXIDLEN; i++)
    ID[i] = 0;
  IDlen = 0;
  
  prime = NULL;
  primeLen = 0;
  segNum = 0;
  
  return 0;
}













  
int secretSharer::addShare(Share * share)
{
  char tempHashBuff[sizeof(Share)];
  char originalHash[32];
  
  
  if(mode != RETRIEVE)
    return SS_BAD_MODE;
  
  if(share == NULL)
    return SS_NO_SHARE;
  
  
  
  //-----Check block digest-----
  
  //cerr<<"Hash indicado en el block  : "<<bin2hex(share->digest, share->digestLen)<<endl;
    
  memcpy(originalHash, share->digest, 32);
  //Ponemos el digest a 0
  memset(share->digest,0,32);
  //Copiamos el share con el digest a 0
  memcpy(tempHashBuff,share,sizeof(Share));
  
  if(memcmp(originalHash, SHA1((const unsigned char *) tempHashBuff, sizeof(Share),NULL),share->digestLen)){//Si no coinciden
    return SS_HASH_CHECK_FAILED;
  }

  //Reescribimos el hash en el share
  memcpy(share->digest, originalHash, 32);
  
  
  //cerr<<"hash calculado             : "<<bin2hex(SHA1((const unsigned char *)tempHashBuff, sizeof(Share),NULL),share->digestLen)<<endl;
  
  
  //--------set or check members---------
  
  if(K==0)
    K = share->k;
  else
    if(K!=share->k)
      return SS_NO_MATCHING_THRESHOLD;
  
  if(IDlen==0){
    memcpy(ID, share->id, share->idLen);
    IDlen = share->idLen;
  }
  else{
    if(IDlen!=share->idLen)
      return SS_NO_MATCHING_ID;
    else if(memcmp(ID, share->id, share->idLen))
      return SS_NO_MATCHING_ID;
  }
  
  if(!prime){
    primeLen = share->pLen;
    prime  = new char [primeLen];
    memcpy(prime, share->p, share->pLen);
  }
  else{
    if(primeLen!=share->pLen)
      return SS_NO_MATCHING_PRIME;
    else if(memcmp(prime, share->p, share->pLen))
      return SS_NO_MATCHING_PRIME;
  }

  if(segNum==0){
    segNum = share->nSegments;
  }else{
    if(segNum != share->nSegments)
      return SS_NO_MATCHING_NUMSEGMENTS;
  }
  
  
  if(!SS){
    try{
      SS = new secretSharing(K,(unsigned char *) prime,primeLen);
    }
    catch(int e){ return SS_ERROR_INITIALIZING_RETRIEVAL;}
  }    

  
  if(N>=inSharesLen){ //Necesita más espacio
    //cerr<<"REALLOC!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"<<endl;
    inShares = (Share**) realloc(inShares, (inSharesLen*2)*sizeof(Share *));
    if(!inShares)
      return SS_ERROR_REALLOCATING_SHARE_ARRAY;
    
    for(int i=inSharesLen; i<inSharesLen*2; i++)
      inShares[i] = new Share;
    
    
    inSharesLen *= 2;
  }
  
  
  memcpy(inShares[N], share, sizeof(Share));
  
  //inShares[N] = copyShare(share);

  
  N++;
  
  
  //cerr<<"///////////////////////// IMPRIMIENDO EN ADDSHARE //////////////////////////////"<<endl;
  //printShares(inShares,N);

  
  return 0;
}

















char * secretSharer::getSecret(int * len){
  
  char       * retval = NULL;
  PlainShare * segmentShares;
  Secret     * revealed;
  int startPoint = 0;

    
  if(mode != RETRIEVE){
    cerr<<"SS_BAD_MODE"<<endl;
    return 0;
  }
  
  if(N == 0){
    cerr<<"SS_NO_SHARES"<<endl;
    return 0;
  }

    
  //Si no hay bastantes shares, error.
  if(N < K){
    cerr<<"SS_NOT_ENOUGH_SHARES"<<endl;
    return 0;
  }

  //Con poner K bastaría, pero si los pongo todos, la clase de menor nivel verifica que no haya duplicados
  segmentShares = new PlainShare [N];
  
  //Aquí escribiremos el secreto para devolverlo. Reservamos ya un tamaño holgado. En el peor caso desperdiciamos 4 Kbytes
  secretBufferLen = inShares[0]->pLen*inShares[0]->nSegments;   //Esto es la long real del buffer

  secretBuffer    = new char [secretBufferLen];      
  memset(secretBuffer,0,secretBufferLen);
  mlock(secretBuffer,secretBufferLen);
  
  secBufNextPos   = 0;     //Siguiente pos libre
  
  
  //Verificación de fraude:
  /*
    Para cada share, revelar el primer segmento solo. Hacer esto
    tantas veces com sea necesario para cubrir N puntos en grupos
    solapados de k elementos. Aunque no es estadísticamente seguro,
    ver qué revelaciones llevan el padding de tipo 1 delante y sugerir
    que los impostores son los miembros de los grupos que no han
    revelado padding y no se encuentran en ningún grupo que sí lo ha
    revelado (aunque podría darse el caso de que )
  */
  
  
  //Para cada segment
  for(int i=0; i<segNum;i++){

    //Para cada share, 
    for(int j=0; j<N; j++){
      segmentShares[j].i     = inShares[j]->segments[i].i;
      segmentShares[j].qiLen = inShares[j]->segments[i].qiLen;
      segmentShares[j].qi    = inShares[j]->segments[i].qi;    //Pasamos un puntero, no lo copiamos, porque internamente no lo modifica
      
      //cerr<<"Segment "<<i<<" Share "<<j<<": "<<endl;
      //cerr<<"i: "<<segmentShares[j].i<<endl;
      //cerr<<"qiLen: "<<segmentShares[j].qiLen<<endl;
      //cerr<<"qi: ";
      //for(int l=0; l<segmentShares[j].qiLen; l++)
      //  cerr<<bin2hex(&segmentShares[j].qi[l],1);
      //cerr<<endl;
    }
            

    try{
      //Revelar el segment
      revealed = SS->reveal(segmentShares, N);
    }catch(int e){
      cerr<<"Failure revealing secret"<<endl;
      //SS_FAILURE_REVEALING_SEGMENT;
      return 0;
    }
    

    //cerr<<"Segment "<<i<<": "<<bin2hex(revealed->data,revealed->len)<<endl;
    
    
    //Al revelar nos ha quitado el cero de delante
    //verificar el pkcs 1 type 1
    
    if(revealed->data[0] != 1){
      cerr<<"Bad revelation: Could not verify padding"<<endl;
      return 0;
    }
    for(int l=1;l<PADLEN-2;l++)
      if(revealed->data[l] != 0xFF){
        cerr<<"Bad revelation: Could not verify padding"<<endl;
        return 0;
      }
    
    if(revealed->data[PADLEN-2] != 0){
      cerr<<"Bad revelation: Could not verify padding"<<endl;
      return 0;
    }

    //Empieza a leer desde el pto siguiente al padding. El -1 es pq al revelar hemos perdido el 0 inicial
    startPoint = PADLEN-1;
    
    
    //y del último segment, si tiene padding pkcs 1 type 2 y quitárselo
    if((i==segNum-1) && (inShares[0]->pkcs1Padded==1)){
      
      //Verificamos el padding
      if(revealed->data[startPoint] != 0){
        cerr<<"Bad revelation: Could not verify last segment padding"<<endl;
        return 0;
      }
      if(revealed->data[startPoint+1] != 2){
        cerr<<"Bad revelation: Could not verify last segment padding"<<endl;
        return 0;
      }
      startPoint+=2;
      
      while( revealed->data[startPoint] !=0 ){
        
        if(startPoint >= revealed->len){
          cerr<<"Bad revelation: Could not verify last segment padding"<<endl;
          return 0;
        }
        
        startPoint++;
      }
      startPoint++; //Al salir, está apuntando al últmo cero del padding, lo desplazamos uno más
      
      if(inShares[0]->padLen != (startPoint-(PADLEN-1))){
        cerr<<"No coincide la long real del pad pkcs2 tipo 2 con la esperada"<<endl;
        cerr<<"Long pad: "<<inShares[0]->padLen<<endl;
        cerr<<"Long real: "<<startPoint-(PADLEN-1)<<endl;
        cerr<<"Trozo de padding: "<<endl;
        for(int j=PADLEN-1; j<startPoint; j++)
            cerr<<bin2hex((unsigned char *) &revealed->data[j],1);
          cerr<<endl;

        //cerr<<"SS_UNEXPECTED_PAD_LENGTH"<<endl
        return 0;
      }
      
      
    }
    else if((i==segNum-1) && inShares[0]->padLen){ //Si es el último y hay pad y no es pkcs1, lo quitamos y ya.
      startPoint+=inShares[0]->padLen;
    }
    
    
    
    //Append el segment a secretbuffer

    memcpy(secretBuffer+secBufNextPos,revealed->data+startPoint, revealed->len - startPoint);

    
    //Aumentamos el punto de inicio en la longitud del segmento que hemos escrito
    secBufNextPos += (revealed->len - startPoint);
    
    if(secBufNextPos >= secretBufferLen){
      cerr<<"Esto no deberia estar pasando. No puede ser que no quede buffer."<<endl;
      return 0;
    }
    
    
    //Delete revealed de forma segura
    memset(revealed->data,0,revealed->len);
    munlock(revealed->data,revealed->len);
    delete revealed->data;
    delete revealed;
    
    
  

  } //Para cada segmento

  
  //Si el usuario sabe que el contenido es una cadena, no tiene por qué recibir la longitud
  if(len != NULL){
    *len = secBufNextPos;
  }


  //Antes no lo copiaba, pero resulta más cómodo porque así devuelvo un buffer de tamaño ajustado y no he de devover 2 longitudes
  retval = new char[secBufNextPos];
  
  
  mlock(retval,secBufNextPos);
  
  memcpy(retval, secretBuffer, secBufNextPos);


  memset(secretBuffer,0,secretBufferLen);
  munlock(secretBuffer,secretBufferLen);
  delete [] secretBuffer;
  secretBuffer = NULL;
  
  return retval;
}

