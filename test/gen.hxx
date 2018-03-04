#ifndef ZZ_CODEGEN_INCLUDE
#define ZZ_CODEGEN_INCLUDE

#include "../objcLib/lib/general.h"

@class Library;
@class Book;
@class Author;
@class BooksToAuthors;

#include "tmp/books.h"
#include "tmp/books1.h"
#include "tmp/bookTitle.h"
#include "tmp/bookAbstract.h"
#include "tmp/authors.h"
#include "tmp/authors1.h"
#include "tmp/authorName.h"
#include "tmp/booksToAuthors.h"
#include "tmp/booksToAuthors1.h"
#include "tmp/booksToAuthors2.h"
#include "tmp/booksToAuthors3.h"
#include "tmp/booksToAuthors4.h"

// -----------------------------------------------
typedef books_LinkedList2 books;
typedef bookTitle_Name bookTitle;
typedef bookAbstract_Name bookAbstract;
typedef authors_LinkedList2 authors;
typedef authorName_Name authorName;
typedef booksToAuthors_2XtoX booksToAuthors;
// -----------------------------------------------


struct ZZS_Library {
    books_LinkedList2Parent;
    authors_LinkedList2Parent;
};
typedef struct ZZS_Library ZZ_Library;

#define ptrList_Library \
- (id) ptrList { \
    books_LinkedList2Parent_ptrList;\
    authors_LinkedList2Parent_ptrList;\
    return self;\
}

struct ZZS_Book {
    books_LinkedList2Child;
    bookTitle_NameParent;
    bookAbstract_NameParent;
    booksToAuthors_2XtoXEntity1;
};
typedef struct ZZS_Book ZZ_Book;

#define ptrList_Book \
- (id) ptrList { \
    books_LinkedList2Child_ptrList;\
    bookTitle_NameParent_ptrList;\
    bookAbstract_NameParent_ptrList;\
    booksToAuthors_2XtoXEntity1_ptrList;\
    return self;\
}

struct ZZS_Author {
    authors_LinkedList2Child;
    authorName_NameParent;
    booksToAuthors_2XtoXEntity2;
};
typedef struct ZZS_Author ZZ_Author;

#define ptrList_Author \
- (id) ptrList { \
    authors_LinkedList2Child_ptrList;\
    authorName_NameParent_ptrList;\
    booksToAuthors_2XtoXEntity2_ptrList;\
    return self;\
}

struct ZZS_BooksToAuthors {
    booksToAuthors_2XtoXRelation;
};
typedef struct ZZS_BooksToAuthors ZZ_BooksToAuthors;

#define ptrList_BooksToAuthors \
- (id) ptrList { \
    booksToAuthors_2XtoXRelation_ptrList;\
    return self;\
}

typedef books_LinkedList2Iterator books_Iterator;
typedef authors_LinkedList2Iterator authors_Iterator;
typedef booksToAuthors_2XtoXIterator booksToAuthors_Iterator;

#endif // ZZ_CODEGEN_INCLUDE
