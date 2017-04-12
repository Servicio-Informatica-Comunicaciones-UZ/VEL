#ifndef __BLOCKTYPES_H__
#define __BLOCKTYPES_H__

#ifdef __cplusplus
extern "C"{
#endif

#define BLOCK_SIZE 10240


struct block_info {

    unsigned char idenString[40];
    unsigned char id[20];
    unsigned int  rzSize;           // reserved zone size
    int cb;                        // current block
    unsigned int  totalBlocks;      // total number of blocks
    unsigned int version;          // format version
    unsigned char hwId[16];
    unsigned char reserved[BLOCK_SIZE - 40 - 20 - 4 - 4 - 4 - 4 - 16]; 
};
typedef struct block_info block_info_t;


/* A block from the object zone */

struct block_object {
  /* Header */
  unsigned char mode;
  unsigned char type;
  unsigned char reservedHeader[8-2];

  /* Information */
  unsigned char info[BLOCK_SIZE - 8 - 8];

  /* padding */
  unsigned char padding[8];
};
typedef struct block_object block_object_t;


#ifdef __cplusplus
}
#endif

#endif
