#pragma once

#include <cstddef>
#include <maxminddb.h>

#define DATA_POOL_NUM_BLOCKS 32

typedef struct MMDB_data_pool_s {
    size_t index;
    size_t size;
    size_t used;
    MMDB_entry_data_list_s *block;
    size_t sizes[DATA_POOL_NUM_BLOCKS];
    MMDB_entry_data_list_s *blocks[DATA_POOL_NUM_BLOCKS];
} MMDB_data_pool_s;

MMDB_data_pool_s *data_pool_new(size_t);
void data_pool_destroy(MMDB_data_pool_s *);
MMDB_entry_data_list_s *data_pool_alloc(MMDB_data_pool_s *);
MMDB_entry_data_list_s *data_pool_to_list(MMDB_data_pool_s *);
