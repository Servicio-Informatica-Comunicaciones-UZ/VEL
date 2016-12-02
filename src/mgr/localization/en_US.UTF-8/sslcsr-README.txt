Steps to install the SSL certificate:
------------------------------------

* All the certificates must be in PEM format


* You must also provide a file with the whole certificate authority
  chain needed to validate the server SSL certificate. That is, it
  will include:
   * The PEM block of the intermediate CA that signed the SSL server
     certificate (if any, but probably).
   * A blank line
   * The PEM block of the intermediate CA that signed the CA above
     (if any).
   * A blank line
   * Succesively the same for any other intermediate CA.
   
   * The last certificate must be the self-signed
     Root CA certificate [INCLUDE IT ALWAYS]


* Once you have your certificate signed, put it on a usb drive, along
  with the CA chain certificates file.
  
  
* You will be able to install the certificate without the permission
  of the key-holding commission.

* You will be asked to select the file contaoinig the certificate and
  then the file containig the CA chain.

* Only a valid and trusted certificate, matching the private key, will
  be allowed. Only a valid chain where all the certificates up to the
  root appear, bottom up, will be allowed.
