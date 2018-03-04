#define PERSIST_APPLE
// HOLLOW TEST DOES NOT USE DISK STORAGE, ONLY CREATES NEW DATA WHEN NEEDED.
// IT'S PURPOSE IS TO TEST THAT THE PROGRAM COMPILES AND RUNS THROUGH
// ALL THE STEPS AS EXPECTED BEFORE WE ADD PERSISTENCE TO IT.
// UNCOMMENT THE NEXT #include WHEN TESTING THE PERSISTENCE.
// //-----------------------------------------
// This is the first step identical to when we were preparing the benchmark
// with ObjectStore
// #define HOLLOW

#include <stdio.h>
#include <time.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <sys/time.h>

#ifdef PERSIST_APPLE
#import <objc/runtime.h>
#endif
#include <locale.h>
#include <Foundation/Foundation.h>
#include <stdbool.h>

#ifndef O_BINARY
#define O_BINARY 0
#endif

#define NSIZE 500

#include "Persist.h"
#include "gen.h"

#include "Library.h"
#include "Book.h"
#include "Author.h"
#include "BooksToAuthors.h"

#define LIBRARY_FILE_FMT    "library_ObjC_%d_%d.dat"
#define LIBRARY_FILE2_FMT    "library2_ObjC_%d_%d.dat"
#define RESULTS_FILE_FMT "results_ObjC_%d_%d.txt"

char *g_libFilename = NULL;
char *g_libFilename2 = NULL;

#define MAX_AUTHORS_PER_BOOK 3
#define BOOKS_TO_AUTHORS_RATIO 5
//some utility functions
time_t GetTimeMillis();
void Log(const char *msg, ...);
void Help();

@interface Result : NSObject
{
@public
    char testName[128];
    int testNo;
    double value;
    Result *next;
}
- (id) init;
@end

@implementation Result
- (id) init
{
    self=[super init];
    testNo=0;
    value=0.0;
    memset(testName, 0, sizeof(testName));
    return self;
}
@end

#define RESULTS_COUNT 12
Result *resultHead=NULL;
Result *resultTail=NULL;


Library *CreateLibrary(bool genAbstract, unsigned booksCount, int saveIt, bool testing);
void OpenLibrary(Library *givenLib, bool testing);
void AddResult(int testNo, const char* name, double value);
void PrintResults();
void WriteResultsToFile(unsigned booksCount, const char* res_filename);
size_t FileSize(const char* filename);

//comparators
int CompBooksByVote(const void *b1, const void *b2);

unsigned stringSum(char *p){
    unsigned s=0; 
    for(; *p; p++){
	s=s + (unsigned char)(*p);
    }
    return s;
}

void prtCheckSums(Library *lib,char *fileName){
    unsigned numBooks=0;
    unsigned numAuthors=0;
    unsigned numLinks=0;
    unsigned bookNameLength=0;
    unsigned bookNameSum=0;
    unsigned authorNameLength=0;
    unsigned authorNameSum=0;
    unsigned abstrLength=0;
    unsigned abstrSum=0;

    Book *bk; Author *auth; BooksToAuthors *lnk; FILE *fp; char *s;

    books_Iterator *bit=[[books_Iterator alloc] init];
    authors_Iterator *ait=[[authors_Iterator alloc] init];
    booksToAuthors_Iterator *lit=[[booksToAuthors_Iterator alloc] init];

    printf("\n==== TESTING DATA VALIDITY =====\n");
    printf("==== MESURED TIMES ARE INVALID ====\n\n");
    fflush(stdout);

    // traverse all authors
    for(auth=[ait fromHead: lib]; auth; auth=[ait next]){
	numAuthors++;
	s=[authorName get: auth];
	if(s!=NULL){
	    authorNameLength=authorNameLength+strlen(s);
	    authorNameSum=authorNameSum+stringSum(s);
	}
    }

    // traverse all books
    for(bk=[bit fromHead: lib]; bk; bk=[bit next]){
	numBooks++;

	s=[bookTitle get: bk];
	if(s!=NULL){
	    bookNameLength=bookNameLength+strlen(s);
	    bookNameSum=bookNameSum+stringSum(s);
	}

	s=[bookAbstract get: bk];
	if(s!=NULL){
	    abstrLength=abstrLength+strlen(s);
	    abstrSum=abstrSum+stringSum(s);
        }

	// traverse all author links for this book
	for(lnk=[lit from1: bk]; lnk; lnk=[lit next1]){
	    numLinks++;
        }
    }

    fp=fopen(fileName,"w");
    fprintf(fp,"TEST SUMS:\n");
    fprintf(fp,"number of books=%u\n",numBooks);
    fprintf(fp,"number of authors=%u\n",numAuthors);
    fprintf(fp,"number of links between books and authors=%u\n",numLinks);
    fprintf(fp,"total length of book titles=%u\n",bookNameLength);
    fprintf(fp,"check sum for book titles=%u\n",bookNameSum);
    fprintf(fp,"total length of abstracts=%u\n",abstrLength);
    fprintf(fp,"check sum for abstracts=%u\n",abstrSum);
    fprintf(fp,"total length of author names=%u\n",authorNameLength);
    fprintf(fp,"check sum for author names=%u\n",authorNameSum);
    fflush(stdout);
    fclose(fp);

    [bit release];
    [ait release];
    [lit release];
}

// ----------------------------------------------------------
// allocate, remove, allocate a few objects and strings
// ----------------------------------------------------------
void testFreeObjects(){
    char *pp,*p0,*p1,*p2,*p3,*p4,*p5,*p6; Book *b1,*b2,*b3,*b4; 
    b4=NULL;
    b1=[[Book alloc] init];
    [bookTitle addNew: b1 cString: "1-book"];

    b2=[[Book alloc] init];
    [bookTitle addNew: b2 cString: "2-book"];
    
    b3=[[Book alloc] init];
    [bookTitle addNew: b3 cString: "3-book"];

    pp=[bookTitle remove: b2];
    [Persist pfree: pp];
    [Persist pfree: b2];

    pp=[bookTitle remove: b1];
    [Persist pfree: pp];
    [Persist pfree: b1];

    b4=[[Book alloc] init];
    [bookTitle addNew: b4 cString: "4-book"];
    [Persist setRoot: b4];

    p0=[Persist palloc: 1000];
    p1=[Persist palloc: 1010];
    p2=[Persist palloc: 1020];
    p3=[Persist palloc: 1030];
    [Persist pfree: p1];
    [Persist pfree: p2];
    p4=[Persist palloc: 1030];
    p5=[Persist palloc: 1008];
    p6=[Persist palloc: 1060];

    [Persist debugPrt: -2 label: "after testing free objects"];
    if(!b4)exit(333);
    int i=1;
    if(i>0)exit(1); // this happens always when we get here
}


int main(int argc, char *argv[])
{
    int i;

    bool testing = false;

    bool create = true;
    bool createOk = false;

    unsigned booksCount = 0;
    bool countOk = false;

    unsigned nthRun = 1;
    bool nthRunOk = false;

    bool genAbstract = false;

    for(i = 1; i<argc; i++)
    {
        if(strcmp(argv[i], "-c")==0)
        {
            create = true;
            createOk = true;
            continue;
        }
        else if(strcmp(argv[i], "-b")==0)
        {
            if(i < (argc-1))
            {
                booksCount = (unsigned)atoi(argv[i+1]);
                countOk = true;
                i++;
                continue;
            }
        }
        else if(strcmp(argv[i], "-a")==0)
        {
            genAbstract = true;
            continue;
        }
        else if(strcmp(argv[i], "-t")==0)
        {
            testing = true;
            continue;
        }
        else if(strcmp(argv[i], "-o")==0)
        {
            create = false;
            createOk = true;
            continue;
        }
        else if(strcmp(argv[i], "-n")==0)
        {
            nthRun = (unsigned)atoi(argv[i+1]);
            nthRunOk = true;
            i++;
            continue;
        }
    }
    if(!createOk || !countOk || !nthRunOk)
    {
        Help();
        return -1;
    }

    // [Persist manageFreeObjects: 1]; // INVOKE FREE LISTS
    [Persist start: 500000000];  // FULL BENCHMARK
    // [Persist start: 128]; // small test for Apple debugging
    // [Persist start: 2000]; // TEST FREE LISTS - needs a larger page
    [Library start];
    [Book start];
    [Author start];
    [BooksToAuthors start];


    // ----------------------------------------------------------
    // Before even starting, play with free storage and a few objects
    // ----------------------------------------------------------
    // testFreeObjects();  // TEST FREE LISTS - it stops the program


    char lib_filename[NSIZE] = {0,};
    char lib_filename2[NSIZE] = {0,};
    char res_filename[NSIZE] = {0,};
    sprintf(lib_filename, LIBRARY_FILE_FMT, booksCount, nthRun);
    sprintf(lib_filename2, LIBRARY_FILE2_FMT, booksCount, nthRun);
    g_libFilename = lib_filename;
    g_libFilename2 = lib_filename2;

    sprintf(res_filename, RESULTS_FILE_FMT, booksCount, nthRun);

    Library *lib=NULL;
    if(create)
    {
        CreateLibrary(genAbstract, booksCount, 1, testing);        
    }
    else
    {        
        OpenLibrary(lib, testing);        
        booksCount = 0;
    }

    PrintResults();
    WriteResultsToFile(booksCount, res_filename);

    Log("\n\nObjC benchmark done\n");
   // getchar();

    return 0;
}

// saveIt=0 do not save the data at the end, saveIt=1 save it
Library *CreateLibrary(bool genAbstract,unsigned booksCount,int saveIt,bool testing)
{
    char buff[513]; unsigned i;

    remove(g_libFilename);
    remove(g_libFilename2);
    srand((unsigned)time(NULL));

    char *v[1],*t[1];
    Library *lib;
    Book *book;
    Author *auth;
    BooksToAuthors *ba;
    unsigned start, time1, time2;
    unsigned count;
    char name[128];
    char *pname;
    unsigned bookAuthCount;
    unsigned writeByCount;

    start = time1 = GetTimeMillis();
    Log("\n\nCreating the library...\n");    
    lib=[Library alloc];
   // lib->booksCount = 0;

    //first create authors
    Log("Generating authors...\n");
    unsigned authorsCount = booksCount>=BOOKS_TO_AUTHORS_RATIO ? booksCount / BOOKS_TO_AUTHORS_RATIO : booksCount;
    // Author **tmpAuth = new Author*[authorsCount];
    Author **tmpAuth=(Author**)calloc(sizeof(Author*),authorsCount);
    for(i=0; i<authorsCount; i++)
    {
	auth = [[Author alloc] init];
        sprintf(name, "%c%c author %d",(rand() % 26) + 65, (rand() % 26) + 65, i+1);
	[authorName addNew: auth cString: name];
        tmpAuth[i] = auth;
	[authors addTail: lib add: auth];
    }

    Log("Generating books...\n");
    //generate books
    int absSize;
    char *abstr;
    booksToAuthors_Iterator *it=[[booksToAuthors_Iterator alloc] init];

    writeByCount=0;
    for(i=0; i<booksCount; i++)
    {
        book = [[Book alloc] init];
        name[0] = '\0'; // empty string
		//generate random book name
        // sprintf(name, "%c%c book %u\0", (rand() % 26) + 65, (rand() % 26) + 65, i+1);
        sprintf(name, "%c%c book %u", (rand() % 26) + 65, (rand() % 26) + 65, i+1);

	[bookTitle addNew: book cString: name];
        book->vote = rand();
	[books addHead: lib add: book];
        //lib->booksCount++;

        if(genAbstract)
        {
            memset(buff, 'a', NSIZE); buff[NSIZE]='\0';
            absSize = rand() % NSIZE + 1;
            absSize = absSize < 16 ? 16 : absSize;
            buff[absSize-1] = '\0';
	    [bookAbstract addNew: book cString: buff];
        }

        //random authors
        bookAuthCount = authorsCount>=MAX_AUTHORS_PER_BOOK ? rand() % MAX_AUTHORS_PER_BOOK : authorsCount;
        bookAuthCount = bookAuthCount==0 ? 1 : bookAuthCount;
        
        count = 0;        
        bool ok;
        //avoid assign one author twice to the same book
        while(true)
        {
            int idx = rand()%authorsCount;
            auth = tmpAuth[idx];           
            ok = true;

            BooksToAuthors *b2a;
            Author *a;
            //iterate already assigned authors of this books
	    for(b2a=[it from1: book]; b2a; b2a=[it next1]){
		    a = [booksToAuthors entity2: b2a];
                if(a==auth)
                {
                    ok = false;
                    break;
                }
            }            
            if(ok)
            {
                ba=[[BooksToAuthors alloc] init];
		[booksToAuthors add: ba ent1: book ent2: auth];
                count++;
		writeByCount++;
            }
            else
            {
                continue;
            }
            if(count==bookAuthCount)
            {
                break;
            }
        }
    }

    Log("starting with %d books\n",booksCount);
    Log("              %d authors\n",authorsCount);
    Log("              %d book-author relations\n",writeByCount);
    Log("each book has a 9 byte title and an abstract between 10-500 bytes");
    Log("each author has a 9 byte name");


    //remove authors with no book
    bool hasBook;
    for(i=0; i<authorsCount; i++)
    {
	    for(ba=[it from2: tmpAuth[i]]; ba; ba=[it next2]){
            hasBook = true;
            break;
        }
        if(!hasBook)
        {
	    [authors remove: lib elem: tmpAuth[i]];
	    pname=[authorName remove: tmpAuth[i]];
        }
    }
    free(tmpAuth);
    [it release];

    time2 = GetTimeMillis();
    Log("Done. Time: %d ms, Total: %d ms\n", time2-time1, time2-start);
    AddResult(1, "Library creation [ms]", time2-time1);

    if(testing)prtCheckSums(lib,"sums1.txt");


    Log("\n\nSorting books by vote...\n");
    time1 = GetTimeMillis();        
    [books sort: CompBooksByVote parent: lib];
    time2 = GetTimeMillis();
    Log("Done. Time: %d ms, Total: %d ms\n", time2-time1, time2-start);
    AddResult(2, "Sort by vote [ms]", time2-time1);

    if(!saveIt)return lib;
       
    Log("\n\nSaving data...\n");
    time1 = GetTimeMillis();

    // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    //  Here you save all the data space, and remember 'lib' to be the root
    //
       [Persist setRoot: lib];
       [Persist save: g_libFilename method: 'P']; 
    //
    //  g_libFilename is the name of the file  
    // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
   
    time2 = GetTimeMillis();
    Log("Done. Time: %d ms, Total: %d ms\n", time2-time1, time2-start);
    AddResult(3, "Library saving [ms]", time2-time1);
    
    unsigned size = FileSize(g_libFilename);
    AddResult(4, "File size [MB]", size / 1000000.);
    return NULL; // data not needed any more
}

// if givenLib==NULL, open data from disk, otherwise forget IO and take givenLib
void OpenLibrary(Library *givenLib, bool testing)
{
    char *v[1],*t[1];
    Library *lib;
    Book *b;
    unsigned start, time1, time2;
    int cnt;
    char *str;
    bool hasBook;

    books_Iterator *it=[[books_Iterator alloc] init];

    start = GetTimeMillis();
    time1 = start;
    Log("Loading data...\n");

    if(givenLib)lib=givenLib;
    else {

    // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    //  Here you load all the data from disk, and return v[0] as the root.
    //  For checking, t[0] is a text string with the name of the
    //  class for the root object, but it is not needed in this program.
    //
       [Persist open: g_libFilename pgIncr: 0];
       lib=(Library*)[Persist getRoot];
    //
    // The DOL equivalent is:
    // util.open(g_libFilename, 1, v, t); 
    // if(util.error()!=0){
    //            Log("Error while opening file %s.\n", g_libFilename);}
    // lib = (Library*)v[0];
    //
    //  g_libFilename is the name of the file.
    // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    
    }
	time2 = GetTimeMillis();
	Log("Done. Time: %d ms, Total: %d ms\n", time2-time1, time2-start);
	AddResult(5, "Data loading [ms]", time2-time1);


    if(testing)prtCheckSums(lib,"sums2.txt");
    

    time1 = GetTimeMillis();
    const int topVoted = 5;
    Log("Print top %d voted books...\n", topVoted);

    cnt = 0;
    for(b=[it fromHead: lib]; b; b=[it next])
    {
        if(cnt>=topVoted)
        {
            break;
        }
	Log("%d. book: %s\n", cnt+1, [bookTitle get: b]);
        cnt++;
    }
    time2 = GetTimeMillis();
	Log("Done. Time: %d ms, Total: %d ms\n", time2-time1, time2-start);
	AddResult(6, "Top voted books [ms]", time2-time1);

    
    time1 = GetTimeMillis();
    const char* find = "Z book";
    Log("Number of books containing '%s' in their title...\n", find);
    cnt = 0;
    for(b=[it fromHead: lib]; b; b=[it next])
    {
	    if(strstr([bookTitle get: b], find)!=NULL)
        {
            cnt++;
        }
    }

    Log("Number of books: %d\n", cnt);
    time2 = GetTimeMillis();
	Log("Done. Time: %d ms, Total: %d ms\n", time2-time1, time2-start);
	AddResult(7, "Search book by title [ms]", time2-time1);


    time1 = GetTimeMillis();
    Log("\n\nRemove one quarter of the books\n");
    booksToAuthors_Iterator *itBas=[[booksToAuthors_Iterator alloc] init];
    booksToAuthors_Iterator *itBat=[[booksToAuthors_Iterator alloc] init];
    BooksToAuthors *b2as, *b2at;
    Author *a;

    cnt = 1;
    for(b=[it fromHead: lib]; b; b=[it next])
    {
        if((cnt%4)==0)
        {
            // remove book
	    [books remove: lib elem: b];
            // remove books name
	    str=[bookTitle remove: b];
	    [Persist pfree : str];

            //remove abstract if any
	    str = [bookAbstract remove: b];
            if(str!=NULL)
            {
	        [Persist pfree : str];
            }
            //remove the relation Book-Author
	    for(b2as=[itBas from1: b]; b2as; b2as=[itBas next1]){
		a = [booksToAuthors entity2: b2as];
                //remove th relation
		[booksToAuthors remove: b2as];
                //if the author does not have any book, remove the author
                hasBook = false;
		for(b2at=[itBat from2: a]; b2at; b2at=[itBat next2]){
                    hasBook = true;
                    break;
                }
                if(!hasBook){
                    //remove author
			[authors remove: lib elem: a];
                    //remove author's name
			str=[authorName remove: a];
	            [Persist pfree : str];
	            [Persist pfree : a];
                }
	        [Persist pfree : b2as];
            }
	    [Persist pfree : b];
        }
        cnt++;
    }
    [itBas release];
    [itBat release];
    [it release];

    time2 = GetTimeMillis();
	Log("Done. Time: %d ms, Total: %d ms\n", time2-time1, time2-start);
	AddResult(8, "Data reduction [ms]", time2-time1);
   

    if(testing)prtCheckSums(lib,"sums3.txt");

    //save reduced data
    Log("Saving reduced data...\n");
    time1 = GetTimeMillis();

    // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    //  Here you save all the data space, and remember 'lib' to be the root
    //
       [Persist setRoot: lib];
       [Persist save: g_libFilename2 method: 'P']; 
    //
    //  g_libFilename2 is the name of the file, note 2 at the end
    //  of the name.
    // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    time2 = GetTimeMillis();
	Log("Done. Time: %d ms, Total: %d ms\n", time2-time1, time2-start);
	AddResult(9, "Reduced data saving [ms]", time2-time1);
        

    unsigned size = FileSize(g_libFilename2);
    AddResult(10, "Reduced file size [MB]", size / 1000000.);
}

void AddResult(int testNo, const char* name, double value)
{
    Result *res=[Result alloc];
    res->next=NULL;
    if(resultHead==NULL){
        resultHead=res;
    }
    else {
	resultTail->next=res;
    }
    resultTail=res;
    
    res->testNo = testNo;
    strcpy(res->testName, name);
    res->value = value;
}

void PrintResults()
{
    int unsigned i; Result *res;
    printf("\nBENCHMARK RESULTS:\n\n");

    printf("----------------------------------------------------------------------------\n");
    printf("TestNo. | Test Name                                             | Value |\n");
    printf("============================================================================\n");
    for(res=resultHead; res; res=res->next){
        printf("   %02d   | %-53s | %-8.2lf |\n", res->testNo, res->testName, res->value);
	fflush(stdout);
    }
    printf("----------------------------------------------------------------------------\n");
}

void WriteResultsToFile(unsigned booksCount, const char *res_filename)
{
    unsigned i; Result *res;
    setlocale(LC_ALL, "");
    FILE *f = fopen(res_filename, "a");

    //books_count
    // testno; test_name; value
    if(booksCount != 0)
    {
        fprintf(f, "\n%d;;;\n", booksCount); fflush(f);
    }
    for(res=resultHead; res; res=res->next){
        char * end = ( res->next==NULL && booksCount!=0) ? "" : "\n";
        fprintf(f, ";%d;%s;%.2lf%s", res->testNo, res->testName, res->value, end); fflush(f);
    }
    if(booksCount!=0)
    {
        fprintf(f, "\n"); fflush(f);
    }
    else
    {
        fprintf(f, "\n");
        fprintf(f, "\n");
        fprintf(f, "\n");
        fprintf(f, "\n");
    }
    fclose(f);
}

time_t GetTimeMillis()
{
	struct timeval now;
    gettimeofday(&now, NULL);
    return (time_t)now.tv_sec*1000 + now.tv_usec/1000;
}

void Log(const char *msg, ...)
{
        va_list argptr;
        va_start(argptr, msg);
        vprintf(msg, argptr);
        va_end(argptr);
}

int CompBooksByVote(const void *b1, const void *b2)
{
    Book *book1 = (Book*)b1;
    Book *book2 = (Book*)b2;

    return book2->vote - book1->vote;
}

size_t FileSize(const char* filename)
{
	struct stat stat_buf;
	size_t size = 0;
	int fh = open(filename, O_RDWR | O_BINARY, S_IREAD);
	if(fh > 0)
	{
		int rc=stat(filename, &stat_buf);
		size= rc==0 ? stat_buf.st_size : 0;
	}
	return size;
}

void Help()
{
    printf("Usage: main.exe [params]\n");
    
    printf("param: (required) either '-c' or '-o', where 'c' means 'create library' and 'o' means 'open library'\n");
    printf("param: (required) '-b <books_count>': number of books to generate\n");
    printf("param: (required) '-n <run_order>': order of the run of this program\n");
    printf("param: (optional with -c) '-a': generate abstract for each book (random size, max. %d bytes)",NSIZE);
} 

#include "gen.m"
