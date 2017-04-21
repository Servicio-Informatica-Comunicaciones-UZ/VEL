/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/


#include <iostream>
#include <sstream>
#include <string>
#include <stdio.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>


#include "secretSharing/secretSharer.h"
#include "storeHandler/storeHandler.h"

using namespace std;


#define CHUNKLEN 256 //Es bastante seguro, y permite almacenar 256*18 bytes (unos 4k). Si resulta demasiado lento, usar 128

#define MAXPATHLEN 2048
#define MAX_DEV_NAME_LEN 1024


int log(const char * msg){
  cerr<<":: "<<msg<<endl;
}





typedef struct{
  int operation;
  char dev[MAX_DEV_NAME_LEN+1];
  char pwd[ST_MAX_PASS_LEN+1]; 
  char newpwd[ST_MAX_PASS_LEN+1];
  char shareDir[4096];
  int shares;
  int threshold;
} Arguments;


//Block to store a key share
typedef struct{
    char header[8];
    secretSharer::Share share;
    char trailer[8];
} ShareBlock;


// Content struct of the text data block (must keep a compatible structure)
typedef struct{
    int idLen;
    unsigned char  id[128];
    int k;
    int len;
    unsigned char data[10084];
} DummyShare;


//Block to store configuration data
typedef struct{
    char header[8];
    DummyShare share;
    char trailer[8];
} NoShareBlock;  //10240

//Block identifier for the secret sharing block types
const unsigned char tipoSS = 0x0f;

const char configBlockId[] = "vtUJI-config";
const char shareBlockId[]  = "vtUJI-keyshare";


/**** Variables Globales ****/

Arguments _args;



int parseCommandLine(int argc, char ** argv){
  
  
  if(argc <2){
    log("Missing arguments");
    return _ERR;
  }
  
  //Determine which op is being performed (1st arg)
  if(!strcmp(argv[1],"checkPwd")){
    _args.operation = 2;
  }
  else if(!strcmp(argv[1],"checkDev")){
    _args.operation = 1;
  }
  else if(!strcmp(argv[1],"readConfig")){  //Will be written on stdout
    _args.operation = 3;
  }
  else if(!strcmp(argv[1],"readKeyShare")){ //Will be written on stdout
    _args.operation = 4;
  }  
  else if(!strcmp(argv[1],"writeConfig")){  //Read from the stdin
    _args.operation = 5;
  }
  else if(!strcmp(argv[1],"writeKeyShare")){  //Read from the stdin
    _args.operation = 6;      
  }
  else if(!strcmp(argv[1],"share")){  //Read from the stdin
    _args.operation = 9;      
  }
  else if(!strcmp(argv[1],"retrieve")){  //Will be written on stdout
    _args.operation = 10;
  }
  else if(!strcmp(argv[1],"format")){
    _args.operation = 8;
  }
  else if(!strcmp(argv[1],"changePassword")){
    _args.operation = 7;
  }
  
  cerr<<argv[1]<<"------->Opcode?:  "<<_args.operation<<endl;
  //cout<<argv[1]<<"------->Opcode2?: "<<_args.operation<<endl;

  for(int i=2; i<argc; i++){
    
    cerr<<i<<": "<<argv[i]<<endl;
    
    //ops 1 to 8.Expecting -d dev and -p pwd (op 1 needs no pwd, but will be ignored if provided)
    if( _args.operation >=1  && _args.operation <=8 ){
      
      if(!strcmp(argv[i],"-d")){
        strncpy(_args.dev, argv[++i],MAX_DEV_NAME_LEN);
      }
      else if(!strcmp(argv[i],"-p")){
        strncpy(_args.pwd, argv[++i],ST_MAX_PASS_LEN);
      }
    }

    //ChangePassword requires also the new password
    if( _args.operation == 7){
      if(!strcmp(argv[i],"-n")){
        strncpy(_args.newpwd, argv[++i],ST_MAX_PASS_LEN);
      }
    }
    
    //On retrieve we expect num of shares and the destination dir for the shares
    else if( _args.operation == 10){
      switch(i){
      case 2:  //numshares
        _args.shares = atoi(argv[i]);
        break;
      case 3:  //dir
        strncpy(_args.shareDir, argv[i],MAXPATHLEN);
        break;
      default:
        return _OK; //No more args
      }
    }
    
    //On share, we expect (ordered): numshares, threshold, shareoutputdir.
    else if( _args.operation == 9){
      
      switch(i){
        
      case 2:  //numshares
        _args.shares = atoi(argv[i]);
        break;
      case 3:  //threshold
        _args.threshold = atoi(argv[i]);
        break;
      case 4:  //dir
        strncpy(_args.shareDir, argv[i],MAXPATHLEN);
        break;
      default:
        return _OK; //No more args
        
      }
      
    }
  }

  return _OK;
}






int readStdin(char ** buff, int * size){
  
  char * aux = NULL;
  int len    = 0;
  int next   = -1;
  int step   = 128;

  
  aux = (char *) realloc(aux, sizeof(char)*(len+step));
  memset(aux, 0, sizeof(char)*(len+step));
  len += step;
  

  do{
    next++;

    //cerr<<"Next: "<<next<<endl;
    //cerr<<"Len:  "<<len<<endl;    

    if(next >= len){
      //cerr<<"NextLen: "<<sizeof(char)*(len+step)<<endl;
      aux = (char *) realloc(aux, sizeof(char)*(len+step));
      memset(&aux[next], 0, sizeof(char)*step);
      len+=step;
    }
    aux[next] = (char) getc(stdin);
  
  }while(!feof(stdin));
  
  //Machacamos el EOF
  aux[next] = '\0';
  
  //cerr<<"Entrada: "<<aux<<endl;

  *buff  = aux;
  *size = next;  //Sino, imprime el EOF
}









//Accede al store y escribe la configuración del sistema de voto o el fragmento de llave
int writeConfig(StoreHandler * cl){
 
  //De momento suponemos que el store no contiene otro bloque como
  //este, y lo escribe a saco. En el futuro, buscar otro igual y
  //machacarlo si existe

  char * buff = NULL;
  int buffsize = 0;
  
  DummyShare config;
  
  //Leemos la config de la stdin
  readStdin(&buff, &buffsize);
  cerr<<"Buff: "<<buff<<endl;
  cerr<<"size: "<<buffsize<<endl;
  
  
  
  //Construimos el bloque de tipo SS falso
  config.idLen = strlen(configBlockId)+1;
  memset(config.id, 0, 128); 
  strcpy((char *) config.id, (const char *) configBlockId);
  config.k     = 1;
  config.len   = buffsize;
  memset(config.data, 0, 10084); 
  memcpy(config.data, buff, buffsize);
  
  cerr<<"------"<<config.id<<"------->"<<config.data<<endl;
  
  
  if( cl->writeBlock((const unsigned char *) &config, sizeof(DummyShare), tipoSS, _TRUE) != _OK){
    log("Error escribiendo bloque de config");
    return _ERR;
  }

  if( cl->sync() != _OK){
    log("Error escribiendo store en fichero");
    return _ERR;
  }
  
}




//Accede al store y lee la configuración del sistema de voto o el fragmento de llave
int readStore(StoreHandler * cl, const char * id){
  

  
  int len = 0;
  int * blockArr = NULL;

  int blocklen = 0;
  unsigned char * block;


  NoShareBlock * blockSt;
  DummyShare * config;
  
  
  fprintf(stderr,"Tipo: %x\n",tipoSS);
  
  //Listamos Bloques
  if( cl->listBlocks(tipoSS, &blockArr, &len) != _OK){
    log("Error listando bloques SS");
    return _ERR;
  }
  
  cerr<<"Blocklist Len: "<<len<<endl;
  
  //Buscamos el primero que, como id, tenga "eLectionLiveServer-config"
  //Se supone que no habrá más. Si los hay porque alguien lo ha manpulado, mala suerte.
  for(int i=0; i<len; i++){
    
    cerr<<"Leyendo bloque "<<blockArr[i]<<endl;
    if( cl->readBlock(blockArr[i], &block, &blocklen) != _OK){
      log("Error leyendo bloque SS");
      return _ERR;
    }

    //cerr<<"----- electionops. bloque leido("<<blocklen<<"):"<<endl<<bin2hex(block,blocklen)<<endl;
    
    
    //Hacemos typecasting a la estructura del bloque

    blockSt = (NoShareBlock *) block;
    
    //cerr<<"----- electionops. contenido del bloque leido:"<<endl<<bin2hex((unsigned char *) &blockSt->share,10224)<<endl;
    
    config = (DummyShare *) &blockSt->share;
    
    cerr<<"Id del bloque:  "<<config->id<<endl;
    //cerr<<"Contenido del bloque:  "<<bin2hex((unsigned char *) &config->data,10084)<<endl;

    //Imprimimos por la stdout
    if(!strcmp((const char *)config->id, (const char *)id)){
      
      //Si es config (string)
      if(!strcmp((const char *)config->id, (const char *)configBlockId)){
        cout<<config->data<<endl;
      }
      //Es keyshare (binario) (ojo. Debe imprimirse todo el bloque, n solo el contenido.)
      else{
        cerr<<"Size of read block: "<<sizeof(DummyShare)<<endl;
        fwrite(config, 1, sizeof(DummyShare), stdout);
      }
      return _OK;
    }
    
  }
  
  //Si llega aquí, es que no había ninguno de config
  
  
  cerr<<"No habia bloques con id: "<<id<<endl;
  
  return _ERR;
}





//Accede al store y escribe el fragmento de la llave
int writeKeyShare(StoreHandler * cl){
  
  //De momento suponemos que el store no contiene otro bloque como
  //este, y lo escribe a saco. En el futuro, buscar otro igual y
  //machacarlo si existe

  char * buff = NULL;
  int buffsize = 0;
  
  //Leemos la share de la stdin
  readStdin(&buff, &buffsize);
  //cerr<<"Buff: "<<buff<<endl;
  cerr<<"size: "<<buffsize<<endl;
  
  
  //Se supone que el bloque ya viene montado como debe ser de la op 'share', con el id adecuado y todo
  
  if( cl->writeBlock((const unsigned char *) buff, buffsize, tipoSS, _TRUE) != _OK){
    log("Error escribiendo bloque de keyshare");
    return _ERR;
  }
  
  if( cl->sync() != _OK){
    log("Error escribiendo store en fichero");
    return _ERR;
  }

}





int doShare(StoreHandler * cl){

  secretSharer * ss;
  int err;
  
  char * buff = NULL;
  int buffsize = 0;

  struct stat st;
  
  secretSharer::Share * shares;
  


  stat(_args.shareDir, &st);
  
  if(!S_ISDIR(st.st_mode)){
    cerr<<_args.shareDir<<" no es directorio"<<endl;
    return _ERR;
  }

  
  ss = new secretSharer((char *) shareBlockId);
  
  err = ss->initSharing(_args.threshold,_args.shares,CHUNKLEN);
  if(err){
    fprintf(stderr,"Error %x initialising sharing\n",err);
    return _ERR; 
  }
  

  //Leemos la contraseña de la stdin
  readStdin(&buff, &buffsize);
  //cerr<<"Buff: "<<buff<<endl;
  cerr<<"size: "<<buffsize<<endl;
  
  //Al leer de stdin, a veces se genera basura al final. AL esribir el secreto, escribir explícitamente un \0  echo -ne "$SECRETO\0" *-*-
  err = ss->updateSecret(buff, strlen(buff)+1);
  if(err == 0){
    cerr<<"Error updating secret, no space?"<<endl;
    return _ERR;
  }
  
  //Generamos los fragmentos
  shares = ss->getShares();
  
  //Borramos y liberamos el secreto
  memset(buff, 0, buffsize);
  free(buff);
  
  //Cada fragmento, lo escribimos en un fichero el dir de fragmentos
  for(int i=0; i<_args.shares; i++){

    FILE * frag;
    string path(_args.shareDir); 
    stringstream out;
    
    out << i;
    
    path+="/keyshare";
    path+=out.str();

    cerr<<"Path: "<<path<<endl;
    
    frag = fopen(path.c_str(),"w");
    
    fwrite(&shares[i], sizeof(secretSharer::Share), 1, frag);
    
    fclose(frag);
    
    //cerr<<"----------Tam Share: "<<sizeof(secretSharer::Share)<<endl;
    //cerr<<bin2hex((unsigned char *) &shares[i],sizeof(secretSharer::Share))<<endl;
  }
  
  return _OK;
}





int doRetrieve(StoreHandler * cl){
  secretSharer * ss;
  int err;
  
  struct stat st;

  int seclen;
  char * retrieved = NULL;
  
  secretSharer::Share share;
  


  stat(_args.shareDir, &st);
  
  if(!S_ISDIR(st.st_mode)){
    cerr<<_args.shareDir<<" no es directorio"<<endl;
    return _ERR;
  }
  
  
  ss = new secretSharer((char *) shareBlockId);
  
  
  if(ss->initRetrieval()){
    cerr<<"Error initialising retrieval"<<endl;
    return _ERR;
  }


  //Leemos y añadimos todas las shares de los ficheros
  for(int i=0;i<_args.shares;i++){

    FILE * frag = NULL;
    string path(_args.shareDir); 
    stringstream out;
    
    //Leemos la share
    out << i;
    
    path+="/keyshare";
    path+=out.str();

    cerr<<"Path: "<<path<<endl;
    
    frag = fopen(path.c_str(),"r");

    if(!frag){
      cerr<<"File not found!"<<endl;
      return _ERR;
    }
    
    fread(&share, sizeof(secretSharer::Share), 1, frag);
    
    fclose(frag);

    //La añadimos
    cerr<<"Adding share "<<i<<endl;
    err = ss->addShare(&share);
    if(err){
      cerr<<"Error "<<err<<"  Adding share "<<i<<endl;
      return _ERR;
    }
    
    //La liberamos
    memset(&share,0,sizeof(secretSharer::Share));
    
    
  }
  
  //Reconstruimos el secreto y lo enviamos por stdout
  retrieved = ss->getSecret(&seclen);

  if(!retrieved){
    cerr<<"Error obteniendo secreto"<<endl;
    return _ERR;
  }

  //Escribimos el secreto por la salida estándar
  cout<<retrieved;
  
  return _OK;
}



int main(int argc, char ** argv) {


  StoreHandler * cl = NULL;
  int stcode = _ERR;
  int ret = 1;

  //inicialización
  _args.operation = 0;
  _args.dev[0] = '\0';
  _args.pwd[0] = '\0';
  _args.newpwd[0] = '\0';
  _args.shareDir[0] = '\0';
  _args.shares = 0;
  _args.threshold = 0;
  
  if (parseCommandLine(argc, argv) != _OK){
    log("Error procesando parametros: ");
    return 1;
  }
  
  cerr<<"----"<<endl;  
  cerr<<"Operation: "<<_args.operation<<endl;
  cerr<<"Password: "<<_args.pwd<<endl;
  cerr<<"Nuevo Password: "<<_args.newpwd<<endl;
  cerr<<"Device: "<<_args.dev<<endl;
  cerr<<"SharesDir: "<<_args.shareDir<<endl;
  cerr<<"Shares: "<<_args.shares<<endl;
  cerr<<"Threshold: "<<_args.threshold<<endl;
  
  
  //Ops 1-8 need store init.
  if( _args.operation >=1 &&  _args.operation <=8 ){
    cl = new StoreHandler();  
    
    if(cl->init(_args.dev) != _OK){
      log("No se pudo localizar el dispositivo.");
      return 1;
    }
  }

  //Ops 2-7 need store login.
  if( _args.operation >=2 &&  _args.operation <=7 ){
    if(cl->login(_args.pwd) != _OK){
      log("No se pudo autenticar sobre el dispositivo.");
      return 1;
    }
  }
  
  
  switch(_args.operation){
    
  case 1: //checkDev
    stcode = _OK;
    break;
    
  case 2: //checkPwd
    stcode = _OK;
    break;
    
  case 3: //readConfig
    stcode = readStore(cl, configBlockId);
    break;

  case 4: //readKeyShare
    stcode = readStore(cl, shareBlockId);
    break;

  case 5: //writeConfig
    stcode = writeConfig(cl);
    break;

  case 6: //writeKeyShare
    stcode = writeKeyShare(cl);
    break;
    
  case 7: //changePassword
    stcode = cl->setPassword(_args.newpwd);
    break;
    
  case 8: //format
    stcode = cl->format(_args.pwd);
    break;
    
  case 9: //share
    stcode = doShare(cl);
    break;
    
  case 10: //retrieve
    stcode = doRetrieve(cl);
    break;
    
  default:
    log("bad Opcode!!!");
    ret = 1;
    //cerr<<"Opcode: "<<_args.operation<<endl;
  }
  
  if(cl != NULL && cl->isLogged()) //Also true on format, but not on share/retrieve
    stcode = cl->logout(); //Will write store file
  
  if(stcode == _OK)
    ret = 0;
  
  return ret; // 0 if OK, 1 if ERR
}







/*
  #Modo de uso:

  #ssOperations format -d $1  -p $pwd   #0 ok  1 error
  #ssOperations changePassword -d $1  -p $pwd -n $newPwd   #0 ok  1 error

  #ssOperations checkPwd -d $1  -p $pwd   #0 ok  1 bad pwd  2 error connect  *-*-
  #ssOperations checkDev -d $1  #0 succesully set  2 error connect  *-*-
  #ssOperations readConfig -d $1  -p $PWD >$TMPDIR/config$READSTORECOUNT
  #ssOperations readKeyShare -d $1  -p $PWD >$TMPDIR/keyshare$READSTORECOUNT
  #ssOperations writeKeyshare -d $DEV  -p $PWD  <$TMPDIR/newpass/keyshare$1    #0 succesully set  1 write error 2 login error  *-*-
  #ssOperations writeConfig -d $DEV  -p $PWD   <"$ESVYCFG" #0 succesully set  1 write error 2 login error  *-*-

  #ssOperations share shares  threshold   sharefilesoutputdir  <secrettoShare *-*-
  #ssOperations share $SHARES $THRESHOLD  $TMPDIR/newpass <secrettoShare
  
  #ssOperations retrieve numshares sharefilesinputdir  >secretRetrieved    *-*-
  #ssOperations retrieve numshares $TMPDIR/shares  >secretRetrieved
*/
