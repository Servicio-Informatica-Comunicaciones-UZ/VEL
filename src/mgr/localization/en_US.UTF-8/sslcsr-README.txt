Steps to install the SSL certificate:
------------------------------------

* All the certificates must be in PEM format

* You will be able to install the certificate without the permission
  of the key-holding commission.

* You must also provide a file with the whole certificate authority
  chain needed to validate the server SSL certificate. That is, it
  will include:
   * The PEM block of the intermediate CA that signed the SSL server
     certificate (if any).
   * A blank line
   * The PEM block of the intermediate CA that signed the CA above
     (if any).
   * A blank line
   * Succesively the same for any other intermediate CA.
   
   * The last certificate must be the self-signed
     Root CA certificate


* Once you hace your certificate installed
