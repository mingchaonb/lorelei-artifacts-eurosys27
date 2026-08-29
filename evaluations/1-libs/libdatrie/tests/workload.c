#include <datrie/trie.h>
#include <stdio.h>
static int entries;
static int total;
static Bool visit(const AlphaChar *key, TrieData value, void *data) { (void)key; (void)data; ++entries; total += value; return TRUE; }
int main(void) {
    AlphaMap *map = alpha_map_new();
    alpha_map_add_range(map, 'a', 'z');
    Trie *trie = trie_new(map);
    AlphaChar cat[] = {'c','a','t',0};
    AlphaChar car[] = {'c','a','r',0};
    AlphaChar dog[] = {'d','o','g',0};
    TrieData value = 0;
    int ok = trie && trie_store(trie, cat, 42) && trie_store(trie, car, 7) && trie_store(trie, dog, 3) &&
             trie_retrieve(trie, cat, &value) && value == 42 && trie_delete(trie, dog) &&
             !trie_retrieve(trie, dog, &value) && trie_enumerate(trie, visit, NULL);
    printf("cat=42 entries=%d total=%d deleted=%d\n", entries, total, !trie_retrieve(trie, dog, &value));
    trie_free(trie);
    alpha_map_free(map);
    return ok && entries == 2 && total == 49 ? 0 : 1;
}
