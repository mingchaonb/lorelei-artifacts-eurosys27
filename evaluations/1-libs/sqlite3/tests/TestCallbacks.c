#include <sqlite3.h>
#include <stdio.h>
#include <stdlib.h>

struct Counts {
   int rows;
   int updates;
   int result;
};

static int row_callback(void *opaque, int columns, char **values, char **names)
{
   struct Counts *counts = opaque;
   (void)names;
   if (columns == 1 && values[0] != NULL)
      counts->result = atoi(values[0]);
   ++counts->rows;
   return 0;
}

static void update_callback(void *opaque, int operation, const char *database,
                            const char *table, sqlite3_int64 rowid)
{
   struct Counts *counts = opaque;
   (void)operation;
   (void)database;
   (void)table;
   (void)rowid;
   ++counts->updates;
}

static void double_value(sqlite3_context *context, int argc, sqlite3_value **values)
{
   if (argc == 1)
      sqlite3_result_int(context, sqlite3_value_int(values[0]) * 2);
}

int main(void)
{
   sqlite3 *database = NULL;
   struct Counts counts = {0, 0, 0};
   char *error = NULL;
   int rc;

   rc = sqlite3_open(":memory:", &database);
   if (rc != SQLITE_OK)
      return 2;
   sqlite3_update_hook(database, update_callback, &counts);
   rc = sqlite3_create_function_v2(database, "double_value", 1,
                                   SQLITE_UTF8, NULL, double_value,
                                   NULL, NULL, NULL);
   if (rc != SQLITE_OK)
      goto fail;
   rc = sqlite3_exec(database,
      "CREATE TABLE numbers(value INTEGER);"
      "INSERT INTO numbers VALUES(21);"
      "SELECT double_value(value) FROM numbers;",
      row_callback, &counts, &error);
   if (rc != SQLITE_OK)
      goto fail;

   printf("rows=%d updates=%d result=%d\n", counts.rows, counts.updates, counts.result);
   sqlite3_close(database);
   return counts.rows == 1 && counts.updates == 1 && counts.result == 42 ? 0 : 4;

fail:
   fprintf(stderr, "sqlite error: %s\n", error != NULL ? error : sqlite3_errmsg(database));
   sqlite3_close(database);
   return 3;
}
