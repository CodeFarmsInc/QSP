// HOLLOW TEST DOES NOT USE DISK STORAGE, ONLY CREATES NEW DATA WHEN NEEDED.
// IT'S PURPOSE IS TO TEST THAT THE PROGRAM COMPILES AND RUNS THROUGH
// ALL THE STEPS AS EXPECTED BEFORE WE ADD PERSISTENCE TO IT.
// UNCOMMENT THE NEXT #include WHEN TESTING THE PERSISTENCE.
// //-----------------------------------------
// This is the first step identical to when we were preparing the benchmark
// with ObjectStore
#define HOLLOW

#include <stdio.h>
#include <Foundation/Foundation.h>
#include "gen.h"
#include "persist.h"


//Entity classes
@interface Library : NSObject
{    
@public
    ZZ_Library ZZds;
}
- (id) ptrList;
PersistInterface;
@end

@implementation Library
PersistImplementation;
// ptrList_Library
- (id) ptrList { 
    Class sc = class_getSuperclass([self class]);
    if(sc != nil && ! [sc isEqual:[NSObject class]]) [super ptrList]; 
    books_LinkedList2Parent_ptrList; 
    authors_LinkedList2Parent_ptrList; 
    return self;
}
@end

//--------------------------
@interface Book : NSObject
{
@public
    ZZ_Book ZZds;
    unsigned vote; //
}
PersistInterface;
@end

@implementation Book
PersistImplementation;
ptrList_Book
@end

int main(int argc, char *argv[])
{

    return 0;
}

#include "gen.m"
