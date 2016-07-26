/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 2; hs-minor-mode: t  -*-*/

#include "../secretSharing.h"

#include <iostream>



#define TESTNUM 1

#define SECRETLEN 2048



using namespace std;



char * bin2hex(unsigned char *bin, int l)
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



static void genPrimeOverlayCB(int code, int arg, void *cb_arg)
{
  if (code == 0)
    cout<<endl<<"Found potential prime!!!!! #"<<(arg + 1)<<" ...";
  else if (code == 1 && arg && !(arg % 10))
    cout<<".";
  else
    cout<<endl<<"Primality verified!!!!!!"<<endl;
}




int main(void){
  
  int n = 5;
  int m = 7;
  
  secretSharing * ss;
  
  PlainShare * shares = NULL;
  
  Secret sec;
  Secret * revealed;
  
  FILE * rnd;

  
  setGenPrimeCB(genPrimeOverlayCB);

  
  
  //cout<<"starting..."<<endl;

  try{
    ss = new secretSharing(n,m,(SECRETLEN/8));
  }
  catch(int e){
    cout<<"Error "<<e<<" creando secretSharing"<<endl;
    return 1;
  }
  
  
  rnd = fopen("/dev/urandom","r");
  
  sec.len    = ss->getSecretByteLen();  
  sec.data   = new unsigned char [sec.len];
  
  for(int i=0; i<TESTNUM; i++){

    cout<<"Prueba "<<i<<endl;

    //Escribimos un secreto en binario, aleatorio y de tam máximo 
    
    //Leemos el primer caracter y nos aseguramos de que no sea \0
    do{ 
      fread(sec.data,sizeof(char),1,rnd);
      //if(!sec.data[0])
      //  cerr<<"sec.data[0]"<<bin2hex(sec.data,1)<<endl;
    }while(!sec.data[0]);
    

    //cout<<"Leyendo resto de cadena aleatoria"<<endl;
    
    fread(sec.data+1,sizeof(char),sec.len-1,rnd);
    

    cout<<"Sharing..."<<endl;
    
    shares = ss->share(sec);
    

    cout<<"Revealing..."<<endl;

    revealed = ss->reveal(shares, m);
    
    delete [] shares;


    if(revealed->len != sec.len){
      cerr<<"Iteración "<<i<<": rev->len: "<<revealed->len<<"  sec.len: "<<sec.len<<endl;
    }
    

    if(memcmp(sec.data, revealed->data, sec.len)){//Si no coinciden
      cerr<<"Iteración "<<i<<": No coincide el secreto."<<endl;   
      cerr<<"Antes   ("<<sec.len<<"): "<<bin2hex(sec.data, sec.len)<<endl;
      cerr<<"Despues ("<<revealed->len<<"): "<<bin2hex(revealed->data, revealed->len)<<endl;	  
    }
    else{
      //cout<<"Iteracion "<<i<<": Correcto."<<endl;
      //cout<<"Antes   ("<<sec.len<<"): "<<bin2hex(sec.data, sec.len)<<endl;
      //cout<<"Despues ("<<revealed->len<<"): "<<bin2hex(revealed->data, revealed->len)<<endl;	  
    }
      
    
    delete revealed;

  }
  
  fclose(rnd);
      
  return 0;
}


//En 214000 pruebas aleatorias no ha fallado excepto en que cuando el número tiene un 0 a la izda, evidentemente, la liberia BN lo obvia y devuelve el secreto sin este, pero no se considera un fallo.


/************  Pruebas obsoletas ******************


  try{

    //ss = new secretSharing(n,m);

    ss = new secretSharing(n,m,idxs);



  }
  catch(int e){
    
    cout<<"La jodimos. --> "<<e<<endl;
    return 1;

  }


  p = ss->getPrime(&plen);
  
  
  //cout<<"P: "<<bin2hex(p,plen)<<endl;

  sec.data = new unsigned char [12];
  sec.len  =10;
  
  strcpy((char *)sec.data, (const char *)"jandemore\0");
  
  
  //No devuelvo la long de shares pq es conocida por el cliente-> m 
  shares = ss->share(sec);
  
  
  
  
  
  cout<<"FUERA"<<endl;
  
  
  for(int i=0; i<m; i++) {
    cout<<"------ Pieza "<<shares[i].i<<" ------"<<endl;
    cout<<bin2hex(shares[i].qi,shares[i].qiLen)<<endl;
    cout<<"---------------------"<<endl;
    
  }


  revealed = ss->reveal(shares, m);

  cout<<endl<<"Secreto revelado: "<<revealed->data<<endl;


  cout<<"Maxsecretbytelength: "<<ss->getMaxSecretByteLength()<<endl;


  try{
  rs = new secretSharing(n,p,plen);
  }catch(int e){
    
    cout<<"La jodimos 2. --> "<<e<<endl;
    return 1;

  }

  try{
  revealed2 = rs->reveal(shares, m);
  }
  catch(int e){
    
    cout<<"La jodimos 3. --> "<<e<<endl;
    return 1;
    
  }
  cout<<endl<<"Secreto revelado desde otro objeto: "<<revealed2->data<<endl;

  return 0;





**************************************************/
