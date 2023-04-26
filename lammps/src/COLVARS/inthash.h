#ifndef INTHASH_H
#define INTHASH_H

namespace IntHash_NS {

  /* re-usable integer hash table code. */

  /** hash table top level data structure */
  typedef struct inthash_t {
    struct inthash_node_t **bucket;        /* array of hash nodes */
    int size;                           /* size of the array */
    int entries;                        /* number of entries in table */
    int downshift;                      /* shift cound, used in hash function */
    int mask;                           /* used to select bits for hashing */
  } inthash_t;

  /** hash table node data structure */
  typedef struct inthash_node_t {
    int data;                           /* data in hash node */
    int key;                            /* key for hash lookup */
    struct inthash_node_t *next;        /* next node in hash chain */
  } inthash_node_t;

#define HASH_FAIL  -1
#define HASH_LIMIT  0.5

  /* initialize new hash table  */
  void inthash_init(inthash_t *tptr, int buckets);
  /* lookup entry in hash table */
  int inthash_lookup(void *tptr, int key);
  /* insert an entry into hash table. */
  int inthash_insert(inthash_t *tptr, int key, int data);
  /* delete the hash table */
  void inthash_destroy(inthash_t *tptr);

} // namespace IntHash_NS

#endif
