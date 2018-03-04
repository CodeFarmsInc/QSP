
// -------------------------------------------------------------
//         Copyright (c) Code Farms Inc. 2012
// Author: Jiri Soukup, jiri@codefarms.com, Nov.25, 2012
// -------------------------------------------------------------
// Persistent utility class which controls allocation and diskIO.
// As a basic, low level service, it is independent of the Foundation classes.
//
// Structure of each allocated object or block of bytes:
//   ind   = index into temporary array tArr, sometimes used as a flag
//   sz    = size of the object
//   count = retainer count used by Objective C, kept as a safety precaution.
//   ------------- the true object starts here -------------------------
//   hidden = hidden pointer inserted by the compiler
//     ... any number of class members (values) as required
//    
// -------------------------------------------------------------
// CONTROLS FOR THE DEBUGGING PRINTS
// -------------------------------------------------------------
// Comment out the next line for debugPrt() to include full unstructured data
#define DOTS_FOR_UNSTRUCTURED_DATA
// 
// Comment out the next line for debugging with a smaller default page
// #define DEBUG_TEST
// -------------------------------------------------------------

#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <fcntl.h>
#ifndef O_BINARY
#define O_BINARY 0
#endif

#import <sys/stat.h>
// #import <mem.h>
#import <Foundation/Foundation.h>

#ifdef DEBUG_TEST
#define defaultPgSz 2000 
#else
#define defaultPgSz 1048576
#endif

#define defaultArrSz 50
#include "Persist.h"

int ptrSz=sizeof(char*);

// object sizes are multiples of 4 
size_t flg_mask=(size_t)3; // lowest 2 bits
size_t size_mask= ~((size_t)3); // anything above 2 bits 

@implementation PersistObject
- (id) ptrList{ return self;}
+ (void) start{ }
+ (void*) getMask{return nil; }
+ (id) alloc {return nil;} 
+ (id) allocArr: (size_t) sz { return nil;}
@end

typedef int (*compfn)(const void*, const void*);

void writeSingleObject(id obj, char style){ // style='P'/'X'/'B'
    switch(style){
	case 'X':
            // archiveAToXmlPlist(obj,@"data.xml");
            // Can it be more general? 
	    // Do we need one archive..() for every class?
            printf("XML serialization    class=%s addr=%llu\n",
			         class_getName([obj class]),(U)obj); 
	    break;
	case 'B':  // binary object-by-object
            printf("binary serialization class=%s addr=%llu\n",
			         class_getName([obj class]),(U)obj);
	    break;
	case 'p': // qsp (page based) persistency
	    printf("this should never be executed\n");
	    break;
    }
    fflush(stdout);
}

struct CFPage {
    char *fill; // next object's header would start here
    char *page; // beginning of the page
    size_t pageSz; // size of this page
};

struct ClassRecord {
    const char *className;
    size_t sz;
    size_t *mask;
    struct ClassRecord *next;
    size_t oldHiddenPtr;
    size_t newHiddenPtr;
};

int cmpPg(struct CFPage *p1,struct CFPage *p2){
    size_t beg1,beg2; 
    beg1=(size_t)(p1->page);
    beg2=(size_t)(p2->page);
    if(beg1 < beg2)return -1;
    if(beg1 > beg2)return 1;
    return 0;
}

int cmpCR(struct ClassRecord **p1,struct ClassRecord **p2){
    size_t val1,val2; 
    val1=(size_t)((*p1)->oldHiddenPtr);
    val2=(size_t)((*p2)->oldHiddenPtr);
    if(val1 < val2)return -1;
    if(val1 > val2)return 1;
    return 0;
}

struct FileHeader {
    size_t root; // old address of the root
    size_t space; // total active space
    size_t startAddr; // starting address of the assumed page
}fileHeader;

struct FreeTableEntry {
    size_t value; 
    void *toHead;
}freeTableEntry;

typedef struct FreeTableEntry * TableType;

// dummy class to make the compiler to recognize method getMask
@interface Cheat : NSObject
+ (void*) getMask;
@end
@implementation Cheat
+ (void*) getMask {return nil;}
@end

@implementation Persist
static size_t objCount=0; // allocator's count of objects
static int lastPg=0; // index of the last Page with allocated page and bitmap
static size_t pgSz=0; // 'normal' size of a page which can be better for arrays
static struct CFPage *pgArr=NULL; // array of Pages
static int pgArrSz=0; // size of pgArr[]
static int headerSz=3*sizeof(char*); // for header stored before every object
static size_t activeSpace=0; // total space of active objects incl. headers
static void* root=NULL;  // root associated with the main data
static void* root0=NULL; // root associated with page0
static char* page0; // starting address of the new page
static size_t minPageAddr=0; // minimum page address
// the following chains uses 'addr' as next, ends with 1 instead of 0
static char *stackBeg; // beginning of the intrusive stack used in algorithms
static char *stackEnd; // end of this stack
static struct ClassRecord *classList=NULL; // list of class records
static size_t numActive=0; // number of active objects recorded in active[]
static char **active=NULL; // temporary array of pointers to active objects
static int isAddrClean=1; // 0 when all addr are not 0.
static int minIndex=1; // initial index range of the free storage as unused
static int maxIndex=0; // initial index range of the free storage as unused
static int startLargeTable=9; // 512 size
static struct FreeTableEntry *smallFreeTable=NULL;
static struct FreeTableEntry *largeFreeTable=NULL; 
static int smallFreeSz,largeFreeSz;
static int useFreeObjects=0;


//  -----------------------------------------------------
//  Call this function with i=0 for automatic removal of free objects
//  on every save() call.
//  When i=1, in addition to this, free objects are reused between the 
//  calls to save().
//  -----------------------------------------------------
+ (void) manageFreeObjects: (int) i { useFreeObjects=i; }

//  -----------------------------------------------------
// store the given space in the free storage, 
// each space knows its size, no need to supply it
//  -----------------------------------------------------
+ (void) pfree: (void*) p { 
    void **pp; size_t sz,L; int i;
    if(useFreeObjects == 0)return;
    sz=[Persist getSz: (char*)p];
    if(smallFreeTable==NULL || largeFreeTable==NULL)return;
    L=largeFreeTable[0].value;
    if(sz<L){
	i=((int)sz)/ptrSz - 1;
	pp=(void**)p;
	*pp=smallFreeTable[i].toHead;
	smallFreeTable[i].toHead=p;
    }
    else {
	i=[Persist findFree: sz purpose: 1];
	pp=(void**)p;
	*pp=largeFreeTable[i].toHead;
	largeFreeTable[i].toHead=p;
    }
    [Persist setFlg: (char*)p flg: 0]; // set as a non-structured object
}

//  -----------------------------------------------------
// get a chunk from free storage, NULL=failed
//  -----------------------------------------------------
+ (void*) getFree: (size_t) sz {
    void *p,*prev,**pp,**pr; size_t L,objSz,minSz; int i;
    if(smallFreeTable==NULL || largeFreeTable==NULL)return NULL;
    L=largeFreeTable[0].value;
    if(sz<L){
	i=((int)sz)/ptrSz - 1;
	p=smallFreeTable[i].toHead;
	if(p==NULL) return NULL;
	pp=(void**)p;
	smallFreeTable[i].toHead=(*pp);
	return p;
    }
    else {
	i=[Persist findFree: sz purpose: 0];
        if(i<0)return NULL;
	p=largeFreeTable[i].toHead;
	if(p==NULL) return NULL;
	// find the first object that fits
	for(prev=NULL ; p; prev=p, p=*pp){
	    pp=(void**)p;
	    pr=(void**)prev;
            objSz=[Persist getSz: (char*)p];
	    if(objSz>=sz){
		if(prev==NULL){
	            largeFreeTable[i].toHead=(*pp);
		}
		else {
	            pr=(void**)prev;
		    *pr=(*pp);
	        }
		return p;
	    }
	}
    }
    return NULL;
}

//  -----------------------------------------------------
//  Return index into largeFreeTable[], -1 if not found.
//  When z=0, it is for the purpose of getting a free object,
//  when z=1, it is for the purpose of storing another free object.
//  In the second case, we use no shortcuts;
//  we return the index, and update the range.
//  -----------------------------------------------------
+ (int) findFree: (size_t) sz purpose: (int) z {
    int rr,r1,r2,iResult,imax; size_t vmax,minValue,maxValue;

    if(sz<largeFreeTable[0].value){
        printf("Free table error: sz=%llu large table starts at %llu\n",
			     (U)sz,(U)(largeFreeTable[0].value));
	return -1;
    }
    r1=minIndex; minValue=largeFreeTable[r1].value;
    r2=maxIndex; maxValue=largeFreeTable[r2].value;
    iResult=0;
    if(z==0){
        if(minIndex>maxIndex)return -1;
	if(minValue>sz || maxValue<sz)return -1;
    } 
    else {
	imax=largeFreeSz-1;
	vmax=largeFreeTable[imax].value;
        if(r1>r2){
	    r1=0;   
	    r2=imax;
	}
	else if(sz>maxValue){r1=r2; r2=imax;} 
	else if(sz<minValue){r2=r1; r1=0;   }
    }

    // binary search between r1 and r2
    while(r2>r1+1){
	rr=(r1+r2)/2;
	if(sz<largeFreeTable[rr].value)r2=rr;
	else r1=rr;
    }
    if(sz<largeFreeTable[r2].value) iResult=r1;
    else iResult=r2;

    //adjust ranges
    if(z==0)return iResult;
    if(iResult<0)return -1;
    if(minIndex > maxIndex){minIndex=imax; maxIndex=0;}
    if(minIndex > iResult)minIndex=iResult;
    if(maxIndex < iResult)maxIndex=iResult;
    if(minIndex == maxIndex){maxIndex++;}
    if(maxIndex > imax){minIndex--; maxIndex--;}        
    
    return iResult;
}

//  -----------------------------------------------------
// establish the data structures for managing free objects
//  -----------------------------------------------------
+ (void) startFree {
    int i; size_t y,x;

    if(! useFreeObjects)return;
    for(i=0, x=1; i<startLargeTable; i++, x=x*2){};
    smallFreeSz=x/ptrSz;
    largeFreeSz=ptrSz*8-startLargeTable;
    minIndex=largeFreeSz-1;
    maxIndex=0;

    smallFreeTable= (TableType)calloc(sizeof(struct FreeTableEntry),smallFreeSz);
    largeFreeTable= (TableType)calloc(sizeof(struct FreeTableEntry),largeFreeSz);
    if(smallFreeTable==NULL || largeFreeTable==NULL){
	printf("WARNING: allocation of free tables failed,\n");
	printf("         continuing without reuse of freed objects\n");
    }
    else {
        // fill the tables
        for(i=0, y=ptrSz; i<smallFreeSz; i++, y=y+ptrSz){
	    smallFreeTable[i].value=y;
	    smallFreeTable[i].toHead=NULL;
	}
        for(i=0; i<largeFreeSz; i++, y=y*2){ // picks up y where it ended before
	    largeFreeTable[i].value=y;
	    largeFreeTable[i].toHead=NULL;
	}
    }
}

+ (void) debugFreeChains: (int) printEmpty {
    int i; void *s;
    if(! useFreeObjects)return;
    if(smallFreeTable==NULL || largeFreeTable==NULL){
        printf("NO FREE TABLES!\n"); fflush(stdout);
        return;
    }
    printf("\nDEBUGGING FREE CHAINS");
    printf("\n---------------------\n");
    printf("smallFreeSz=%d largeFreeSz=%d minIndex=%d maxIndex=%d startLargeTable=%d\n",
            smallFreeSz,largeFreeSz,minIndex,maxIndex,startLargeTable);
    printf("\nSMALL TABLE:");
    printf("\n------------\n");
    for(i=0; i<smallFreeSz; i++){
	s=smallFreeTable[i].toHead;
	if(s==NULL && !printEmpty)continue;
	printf("[%d] %llu %llu]=",i,(U)(smallFreeTable[i].value),(U)s);
	if(s!=NULL)[Persist debugChain: s];
	else printf(" 0\n");
    }

    printf("\nLARGE TABLE:");
    printf("\n------------\n");
    for(i=0; i<largeFreeSz; i++){
	s=largeFreeTable[i].toHead;
	if(s==NULL && !printEmpty)continue;
	printf("[%d] %llu %llu]=",i,(U)(largeFreeTable[i].value),(U)s);
	if(s!=NULL)[Persist debugChain: s];
	else printf(" 0\n");
    }
    printf("\n");
}

+ (void) debugChain: (void*) head {
    void *p, **pp; int flg; size_t sz;
    for(p=head; p; p=(*pp)){
        sz=[Persist getSz: (char*)p];
        flg=[Persist getFlg: (char*)p];
	pp=(void**)p;
	printf("  (%llu)[%d]%llu/%llu",(U)sz,flg,(U)p,(U)(*pp)); fflush(stdout);
    }
    printf("\n"); fflush(stdout);
}

+ (void) outsideStart: (Class) klass params: (persist_params*) data {
    if(data->mask != NULL) return; 
    data->mySz=class_getInstanceSize(klass); 
    [Persist createMask: klass params: data];
    const char *cName=class_getName([klass class]);
    [Persist reportClass: cName sz: data->mySz mask: data->mask]; 
} 

+ (void) createMask: (Class) klass params: (persist_params*) data {
    void *sMask; Class superClass,*p; int i,sz,sSz; char *m,*s; 
    if(data->mask != NULL) return; 
    data->mySz=class_getInstanceSize(klass); 
    sz= class_getInstanceSize(klass);
    // data->mask = (void*)[[klass class] alloc]; // causes crash in rr2.bat
    p = (Class*)calloc(sz,1);
    *p = klass; /* replace beginning of the object */
    data->mask = (void*)p;

    [(id)data->mask ptrList]; 
    superClass = class_getSuperclass(klass); 
    // next line does not compile with NSObject instead of PersistObject
    if(superClass != nil && ! [superClass isEqual: [PersistObject class]]) { 
        [superClass start]; 
	/* merge the two masks */ 
	sMask=[superClass getMask]; 
	if(sMask==nil){
	    printf("internal error, class=%s has no mask\n",
                       class_getName([klass class])); fflush(stdout);
	    exit(2);
	}
        sSz=class_getInstanceSize(superClass); 
	s=(char*)sMask; 
	m=(char*)(data->mask); 
	for(i=sizeof(char*); i<sSz; i++) {m[i]=m[i] | s[i];} 
    } 
} 

+ (id) outsideAlloc: (Class) klass params: (persist_params*) data {
    Class *p; 
    size_t sz=class_getInstanceSize(klass);
    p= (Class*)[Persist palloc: sz];
    *p=klass; /* replace beginning of the object */ 
    [Persist setFlg: (char*)p flg: 1];
    data->count++; 
    return (id)p;
} 

+ (id) outsideAllocArr: (Class) klass params: (persist_params*) data size: (size_t) sz {
    Class *p; char*s,**pp,**ss; int i;
    p=(Class*)[Persist palloc: sz*(data->mySz)]; 
    *p=klass; /* replace beginning of the first object */ 
    pp=(char**)p; 
    for(i=0, s=(char*)p; i<sz; i++, s=s+(data->mySz)){ 
       ss=(char**)s; 
       *ss=(*pp); /* reset all hidden pointers */ 
    } 
    [Persist setFlg: (char*)p flg: 1]; 
    data->count=data->count+sz; 
    return (id)p;
} 

+ (void*) palloc: (size_t) sz {  // sz=size in bytes
    int pgInd; char *p;

    if(sz>pgSz - 3*ptrSz){
      printf("size of object or array must be <= pageSize - 3* pointerSize");
      printf("\n   %u > %u, cannot continue ...\n",sz,pgSz-3*ptrSz);
      exit(1);
    }

    sz=((sz+ptrSz-1)/ptrSz)*ptrSz; // round up sz to the multiple of ptrSz
    if(useFreeObjects > 0){
	p=(char*)[Persist getFree: sz];
	if(p){
	    objCount++;
	    return (void*)p;
	}
    }
    pgInd=lastPg; // initialize for the compiler, this is the 'normal' case
    if(sz+headerSz > 
       ((size_t)(pgArr[lastPg].page) + pgSz) - (size_t)(pgArr[lastPg].fill)){
	    pgInd=[Persist addPage: sz];
    }
    p=pgArr[pgInd].fill + headerSz;
    pgArr[pgInd].fill = p + sz;
    [Persist setSz: p size: sz];
    objCount++;
    return (void*)p;
}

+ (void*) allocPtrArr: (size_t) sz {  // sz=number of pointers
    char *v=(char *)[Persist palloc: sz*ptrSz];
    [Persist setFlg: v flg: 2]; // pointer array has flag 2
    return v;
}

// c='X' for XML serialization, ='B' for binary serialization, ='P' memory page
// All data remain in their existing positions. The pages will change their
// order but the application does not even know about it. After saving, 
// the objects are still in the same addresses.
// ---------------------------------------------------------------------
// Selection of the method:
// 'X' for XML serialization
// 'B' for binary serialization
// 'P' saving memory pages, keeping the same data
// 'C' after saving, switching to smaller, cleaner data representation as 1 page
// WARNING:
// Method 'C' makes any references to the data invalid. The application
// must start after saving from the new root, using [Persist getRoot].
// ---------------------------------------------------------------------
+ (void) save: (char*) fileName method: (char) c {
    if(c=='X' || c=='B'){
	[Persist algorithmA: 1]; // 1=generate output
	return;
    }
    else if(c=='P'){
	[Persist algorithmA: 0]; // 0=no output, just first stage for AlgorithmB
	[Persist algorithmB: fileName pageIncr: 0 cutoff: 0.0 control: 'O'];
    }
    else if(c=='C'){
	[Persist algorithmA: 0]; // 0=no output, just first stage for AlgorithmB
	[Persist algorithmB: fileName pageIncr: 0 cutoff: 0.0 control: 'N'];
    }
    else {
	printf("WRONG save() mode: c=%c (X/B/P)\n",c); fflush(stdout);
	printf("Data not saved!!\n"); fflush(stdout);
    }
}

// Open data saved on file, including the root reference. Use
//   keep=1 for keeping any old data, =0 for removing any old data.
//   incr=page increment over the data coming from the file (as one page),
//        use 0 if you want to keep the same page size.
// NOTE: The page size of the data coming from the file will overwrite the
//  page you may have set in the [Persist start: pageSize] call.
//  ------------------------------------------------------------------------
+ (void) open: (char*) fileName pgIncr: (size_t) incr{
    int fh,i,nameSz; struct ClassRecord *cr,*oldClassList,*crNext; size_t sz,rec;
    
    //...............................................
    fh= open(fileName,O_RDWR | O_CREAT | O_BINARY, S_IREAD | S_IWRITE);
    if(fh<0){
	printf(" cannot open file: %s to read the data\n",fileName); fflush(stdout);
	printf("UNABLE TO PROCEED !!n"); fflush(stdout);
        exit(11);
    }

    //...............................................
    // Even if removal is not required, but there is only an initial
    // empty page, remove it.
    // remove any old data
    for(i=0; i<=lastPg; i++){
        free(pgArr[i].page);
        pgArr[i].fill=NULL;
        pgArr[i].pageSz=0;
    }
    free(pgArr);
	
    //...............................................
    // read the headers
    oldClassList=[Persist readHeaders: fh]; // returns the start of the old list
    // start new persistent environment based on the space coming from the file
    sz=fileHeader.space;
    [Persist start: sz+incr];

    //...............................................
    // read the page from the file
    rec=read(fh,pgArr[0].page,sz);
    close(fh);
    if(rec!=sz){
	printf("read only %llu from requested %llu bytes,\n",(U)rec,(U)sz);
	printf("UNABLE TO CONTINUE !!\n"); 
	fflush(stdout);
	exit(12);
    }
    pgArr[0].fill=pgArr[0].page+sz;

     // keep the next line commented out
    //...............................................
    // Traverse all objects in the new page and swizzle all their pointers.
    // This is a bit different from what we did in Algorithms A and B,
    // because we have to convert the hidden pointers in order to identify
    // the classes of the objects.
    // 
    // The basic formula for regular pointers is: newPtr=newPg+(oldPtr-oldPg)
    // To convert hidden pointers swiftly, we use a sparse array with direct
    // indexing - no searches involved.
    //...............................................
    {
	char *nxtObj; int i,k,flg;
       	size_t fill,u,objSz,mySz,oldPgAddr,base,slot,hidden;
	size_t *sparse,*mask,*targPtr;

	// Prepare sparse conversion table for hidden pointers.
	// Hidden pointers, both old and new, can be find at the first position
	// of the mask, which is stored in each ClassRecord.
	// When preparing this table, we also check for compatibility of
	// the old and new classes.
	sparse=[Persist hiddenPtrTable: oldClassList base: &base slot: &slot];
	// With this table, we convert like this:
	//    newHiddenPtr = sparse[(oldHiddenPtr-base)/slot];

	
	page0=pgArr[0].page;
	fill=(size_t)(pgArr[0].fill);
	oldPgAddr=fileHeader.startAddr; // starting address of the old page


	objSz=0; // to stop compiler complains
	mySz=0;  //  -"-

	for(u=(size_t)page0+headerSz; u<fill; u=u+headerSz+objSz){
	    nxtObj=(char*)u;
	    flg=[Persist getFlg: nxtObj];
	    objSz=[Persist getSz: nxtObj];
	    if(flg==0)continue; // no pointers to swizzle
	    // --------------------------------------------------------
	    if(flg==1){ // both regular and hidden pointers, possibly an array
		if(sparse==NULL){
		    printf("internal error, flg=1 but sparse=NULL\n");
		    fflush(stdout);
	            exit(19);
		}
		// first convert the hidded pointer 
		targPtr=(size_t*)nxtObj;
		hidden=sparse[(*targPtr - base)/slot];
                // for one object, next line swizzles its hidden pointer
		// for an array of objects, it swizzles it for the first object
		*targPtr=hidden; 
		// get the size of the single object, mySz, and the mask
	        mySz=class_getInstanceSize([(id)nxtObj class]);
		mask=(size_t*)[[(id)nxtObj class] getMask];
		// the following loop works for both single object and an array
		// i walks through all objects, k repeatedly through the mask
		for(i=k=0; i<objSz; i=i+ptrSz, k++){
		    if(k>=mySz)k=0;
		    if(k==0 && i!=0){ 
			// for the beginning of any object in an array
			// except for the first object
		        targPtr=(size_t*)(nxtObj+i);
		        *targPtr=hidden;
	            }
		    else if(mask[k]!=1)continue;
		    else {
		        targPtr=(size_t*)(nxtObj+i);
		        if(*targPtr==0)continue; // no conversion, NULL pointer
		        *targPtr=(size_t)page0+((size_t)(*targPtr) - oldPgAddr);
		    }
		}
	    }
	    if(flg==2){  // array of pointers
		for(i=0; i<objSz; i=i+ptrSz){
		    targPtr=(size_t*)(nxtObj+i);
		    if(*targPtr==0)continue; // no conversion, NULL pointer
		    *targPtr=(size_t)page0+((size_t)(*targPtr) - oldPgAddr);
		}
	    }
	}
        //convert the reference to the root
        root=(char*)[Persist getRoot];
        root=(char*)((size_t)page0+((size_t)(root) - oldPgAddr));
        [Persist setRoot: root];

        //...............................................
        // release the entire oldClassList
        for(i=0, cr=oldClassList; cr; i++, cr=crNext){
	    free((char *)(cr->className)); // we know this name WAS allocated
	    free(cr->mask);
	    crNext=cr->next;
	    free(cr);
        }
        // release the sparse table
        free(sparse);
    }
}

// --------------------------------------------------------------------
+ (size_t *) hiddenPtrTable: (struct ClassRecord *) oldClassList
			      base: (size_t *) pBase slot: (size_t *) pSlot {
    struct ClassRecord *cro,*crn;
    size_t i,dif,k,n,err,*msko,*mskn,sparseSz;

    // while preparing the table, make a rough check that all the old classes
    // are present, and that the masks and sizes did not change.
    // err will be bit-packed: 01 needs more sophisticated approach,
    //    02 means that at least one class now has different size of mask.
    for(cro=oldClassList, crn=classList, err=0; cro && crn; 
	                                    cro=cro->next, crn=crn->next){
        cro->newHiddenPtr=0;
        if(strcmp(cro->className,crn->className)){err=err | 01; continue;}
	if(cro->sz != crn->sz){err=err | 02; break;}
	msko=(size_t*)(cro->mask);
	mskn=(size_t*)(crn->mask);
	for(k=1; k<(cro->sz)/ptrSz; k++){
	    if(msko[k]!=mskn[k]){err=err | 02; break;} // masks not compatible
	}
	if(err & 02)break;
	// these two classes pass the check
	cro->oldHiddenPtr=msko[0];
	cro->newHiddenPtr=mskn[0];
    }
    if(err & 02){
	printf("QSP style persistence cannot handle classes that changed;\n");
	printf("Use XML serialization for this purpose.\n");
	fflush(stdout);
	exit(14);
    }

    // ....................................................
    if(err==01){ // records may be just in a different order
	// The number of classes is usually not high, and if it is
	// it is a major problem where the double-loop overhead here
	// should not matter much.
        for(cro=oldClassList; cro; cro=cro->next){
	    if(cro->newHiddenPtr)continue; // in case the first try found it
	    msko=(size_t*)(cro->mask);
	    cro->oldHiddenPtr=msko[0];
	    cro->newHiddenPtr=1; // 1 means that new counterpart does not exist
            for(crn=classList; crn; crn=crn->next){
	        msko=(size_t*)(cro->mask);
                if(!strcmp(cro->className,crn->className)){
		    cro->newHiddenPtr=mskn[0];
		    break;
		}
	    }
	    // if not reset, cro->newHiddenPtr remains 1, as not found
	}
    }

    // ....................................................
    // find the number n of old classes
    for(cro=oldClassList, n=0; cro; cro=cro->next){
        n++;
    }
    if(n==0)return NULL;

    // make array of pointers to old class records
    struct ClassRecord **cArr=calloc(ptrSz,n);
    if(!cArr){
        printf("error in allocating a small internal array\n");
        printf("CANNOT CONTINUE, SORRY !!\n");
	fflush(stdout);
        exit(15);
    }
    // fill the array with references to the old records
    for(cro=oldClassList, i=0; cro; cro=cro->next, i++){
        cArr[i]=cro;
    }
    // sort the array with oldHiddenPtr as the key
    qsort((void*)cArr,n,ptrSz,(compfn)cmpCR);

    // find base and slot for the future sparse array:
    // base will be the minimum of oldHiddenPtr which is > 1.
    // slot the minimum distance between adjacent oldHiddenPtr values
    // ....................................................
    *pBase=cArr[0]->oldHiddenPtr;
    *pSlot=ptrSz; // any positive number for n==1
    for(i=1; i<n; i++){ 
        dif=cArr[i]->oldHiddenPtr - cArr[i-1]->oldHiddenPtr;
	if(i==1 || *pSlot>dif) *pSlot=dif;
    }
    if(*pSlot==0){
        printf("iternal error - different classes with the same hidden ptr\n");
        printf("CANNOT CONTINUE, SORRY !!\n");
	fflush(stdout);
        exit(16);
    }

    // last h2 is the highest value of oldHiddenPtr
    // create the sparse array for the fast lookup
    // ....................................................
    sparseSz=(cArr[n-1]->oldHiddenPtr - (*pBase))/(*pSlot) + 3;
                               // 3 takes care of the algorithm and roundoff
    size_t *sparse=calloc(sizeof(size_t),sparseSz);
    if(!sparse){
	    printf("error: cannot allocate sparse array size=%llu\n",(U)i);
        printf("CANNOT CONTINUE< SORRY !!\n");
	fflush(stdout);
        exit(17);
    }
    for(i=0; i<n; i++){
	k=(cArr[i]->oldHiddenPtr - *pBase)/(*pSlot);
	sparse[k]=cArr[i]->newHiddenPtr;
	if(sparse[k]==0){
	    printf("internal error in the conversion of hidden pointers\n");
            printf("CANNOT CONTINUE, SORRY !!\n");
	    fflush(stdout);
	    exit(18);
	}
    }

    free(cArr); 
    return sparse;
}
	    

// fh is the file handle of the file to read from.
// Returns entry to the old list of class records; the new one is in classList
// -----------------------------------------------------------------------
+ (struct ClassRecord*) readHeaders: (int) fh {
    int rec,error; size_t sz,nameSz,uSz; char *p;
    struct ClassRecord *cr,*oldList,*tail;

    //...............................................
    uSz=sizeof(size_t);
    sz=sizeof(struct FileHeader);
    rec=read(fh,&fileHeader,sz);
    if(rec!=sz){
        printf("error in reading the file header, sz=%llu rec=%llu\n",(U)sz,(U)rec);
	printf("NO SENSE TO CONTINUE !!\n");
	fflush(stdout);
	exit(12);
    }
    root=(char*)fileHeader.root;
    activeSpace=fileHeader.space;
    //...............................................
    oldList=tail=NULL;
    for(error=0; ; ){ // loop until reading sz=0
	// ....................................................
	rec=read(fh,&sz,uSz); if(rec!=uSz)error=error | 01;
	if(sz==0)break;
	cr=(struct ClassRecord*)calloc(1,sizeof(struct ClassRecord));
	if(!cr){
	    printf("problem to allocate ClassRecord\n");
	    printf("CANNOT CONTINUE !!\n");
	    fflush(stdout);
	    exit(14);
	}
	if(oldList==NULL)oldList=tail=cr; 
	else {tail->next=cr; tail=cr;}
        cr->next=NULL;
	cr->sz=sz;
	cr->mask=NULL;
	cr->className=NULL;
	// ....................................................
	rec=read(fh,&nameSz,uSz); if(rec!=uSz)error=error | 02;

        p=calloc(sz,1);
	if(!p)error=error | 04;
	else{
	// ....................................................
	    rec=read(fh,p,sz);
	    if(rec!=sz)error=error | 010;
	    else cr->mask=(size_t*)p;
	}
        p=calloc(nameSz,1);
	if(!p)error=error | 020;
	else{
	// ....................................................
	    rec=read(fh,p,nameSz);
	    if(rec!=nameSz)error=error | 040;
	    else cr->className=p;
	}
	if(error){
	    printf("error in reading old class table, code=%o\n",error);
	    printf("NO SENSE TO CONTINUE !!\n");
	    fflush(stdout);
	    exit(13);
	}
    }
    return oldList;
}

// Remove all dead objects and shift all active objects in a new, single page.
// All references in your program will become invalid !!
// [Persist getRoot] will get you the new root.
+ (void) cleanup {
	[Persist algorithmA: 0]; // 0=no output, just first stage for AlgorithmB
	[Persist algorithmB: 0 pageIncr: 0 cutoff: 0.0 control: 'N'];
	return;
}


+ (void) start: (size_t) totalSize {
    if(sizeof(size_t)!=sizeof(char*)){
	if(sizeof(size_t)==8){
	    printf("use #define BITS64 in persist.h");
	}
	else if(sizeof(size_t)==4)printf("comment out #define BITS64 in persist.h");
	else printf("strange: pointer=%llu int=%llu bytes do not agree\n",
	             sizeof(char*),sizeof(size_t));
	fflush(stdout);
	return;
    }

    if(totalSize)pgSz=totalSize;
    else pgSz=defaultPgSz;
    pgArr=calloc(defaultArrSz,sizeof(struct CFPage));
    if(pgArr==NULL) {
	printf("ERROR to allocate pgArr\n"); fflush(stdout);
	exit(1);
    }
    pgArrSz=defaultArrSz;
    lastPg= -1;
    [Persist addPage: pgSz-headerSz];

    [Persist startFree];
}

// Add page so that it will accomodate object of size sz.
// Returns the index of the page that should be used for this,
// it may not be the last page!! If the new page is larger than pgSz,
// and will be fully used by this object, this method inserts the new
// page as the one-before-last. Consequently, the page that was
// previously last and may still have some space, will appear again as last.
+ (int) addPage: (size_t) sz {
    size_t newPgSz; int retPageInd;

    if(sz+headerSz > pgSz)newPgSz=sz+headerSz; else newPgSz=pgSz;
    if(lastPg+1 >= pgArrSz) [Persist enlargePgArr];

    if(newPgSz>pgSz && lastPg>=0){ // special large page, move lastPg to lastPg+1
	 pgArr[lastPg+1].page=pgArr[lastPg].page;
	 pgArr[lastPg+1].fill=pgArr[lastPg].fill;
	 pgArr[lastPg+1].pageSz=pgArr[lastPg].pageSz;
	 retPageInd=lastPg;
    }
    else {
	retPageInd=lastPg+1;
    }

    pgArr[retPageInd].page  =calloc(newPgSz,1);
    if(pgArr[retPageInd].page==NULL) {
	printf("ERROR to allocate page\n"); fflush(stdout);
	exit(3);
    }
    pgArr[retPageInd].fill=pgArr[retPageInd].page;
    pgArr[retPageInd].pageSz=newPgSz;
    lastPg++;
    return retPageInd;
}
    
+ (void) enlargePgArr {
    struct CFPage *pg,*arr; int newPgArrSz;
    newPgArrSz=pgArrSz+defaultArrSz;
    arr=calloc(sizeof(struct CFPage),newPgArrSz);
    if(arr==NULL) {
	printf("ERROR to enlarge pgArr\n"); fflush(stdout);
	exit(2);
    }
    memcpy(arr,pgArr,pgArrSz*sizeof(struct CFPage)); 
    free(pgArr);
    pgArr=arr;
    pgArrSz=newPgArrSz;
}

// reset addr=0 on all objects
+ (void) cleanAddr {
    size_t i,fil,obj,sz;
    for(i=0; i<=lastPg; i++){ // go through all pages
	fil=(size_t)(pgArr[i].fill);
	// traverse objects within the page using the size information
	for(obj=(size_t)(pgArr[i].page)+headerSz; obj<fil; obj=obj+sz+headerSz){
	    sz=[Persist getSz: (char*)obj];
	    [Persist setAddr: (char*)obj addr: 0];
	}
    }
    isAddrClean=1;
}

/* -------------------------------------------------------------
ALGORITHM A: Serialization
(mark all active objects with ind=1, possibly write them to disk)

Stage:
ptrSz is the size of pointer, in bytes.
Allocator sets addr=0 on all objects, but if this algorithm was
used before in this run, e.g. when saving intermediary results, we have
to reset them before we start this algorithm. The state of addr
is recorded in 'isAddrClean'.

returns:
    activeSpace; // space needed for all active objects
NOTE: Stack is only temporary and disassembled at the end this method.
      It uses addr=1 instead of NULL at the end.
  -------------------------------------------------------------- */

+ (void) algorithmA: (int) genOutput // 1 serialization, 0 finds active objects
{
    char *nxtObj,**targPtr,*p; int i,k,flg; size_t sz,mySz,*mask; 

    mySz=0;
    if(!isAddrClean)[Persist cleanAddr];
    activeSpace=0;
    if(root==NULL){
	printf("ERROR set root in the beginning of the run\n"); fflush(stdout);
	exit(5);
    }
    // place root in the stack
    isAddrClean=0;
    stackBeg=stackEnd=(char*)root;
    [Persist setAddr: root addr: 1]; // 1 marks the end of chain
    while(stackBeg!=(char*)1){
	nxtObj=stackBeg;
	flg=[Persist getFlg: nxtObj];
	sz=[Persist getSz: nxtObj]; // allocated size
	activeSpace=activeSpace + headerSz + sz;

	if(genOutput && flg==1){
	    writeSingleObject( (id)nxtObj,'P' ); // serialization
	}

        if(flg>0){ // for 0: no pointers, no expansion
            if(flg==1){ // object with hidden pointer
		mask=(size_t*)[[(id)nxtObj class] getMask];
		if(!mask){
		    printf("failure to get the pointer mask\n"); fflush(stdout);
		    exit(8);
		}
	        mySz=class_getInstanceSize([(id)nxtObj class])/ptrSz; 
            }
            for(i=k=0; i<sz; i=i+ptrSz, k++){ // all ptr locations
		if(k>=mySz)k=0;
                p=nxtObj+i;
                if(flg==1 && mask[k]!=1)continue; // skips 0 or hidden ptr
                targPtr=(char**)p;
                if(*targPtr==NULL)continue;
	        if([Persist getAddr: (*targPtr)])continue; // registered object
                // place *targPtr at the end of the stack
		p=(char*)(*targPtr);
		[Persist setAddr: p addr: 1];
		[Persist setAddr: stackEnd addr: (size_t)p];
		stackEnd=p;
            }
        } 
	
	// move nxtObj from the stack to the list
	stackBeg=(char*)[Persist getAddr: stackBeg];
    }

    // This function really returns: 
    //    activeSpace = total space of active objects including their headers
    // Active objects are marked with addr!=0.
}

// Sort pages using qsort()
+ (void) sortPages {
    qsort((void*)pgArr,lastPg+1,sizeof(struct CFPage),(compfn)cmpPg);
}

/* -------------------------------------------------------------
   ALGORITHM B: Cleanup, compression, option: sending data do disk.
(eliminates discarded objects and compresses all data into one page). 

Stage:
Algorithm A was performed, addr!=0 marks active objects.
Main concern:
The old data must remain in their memory locations, unchanged.
Otherwise using save() in the middle of a run would invalidate all 
the references in the program.
   -------------------------------------------------------------- */
// fileName= output file, NULL for just continuing with clean data
// pgIncr = number of bytes to add to the page size (when anticipating more data
// co = cutoff, for example if co=0.1, and we have all data in one page,
//     then unless there is more then 10% of dead space, the function will 
//     be bypassed. co=0.0 will enforce the algorithm unconditionally.
// -------------------------------------------------------------
+ (void) algorithmB: (const char*) fileName
	 pageIncr: (size_t) pgIncr cutoff: (float) co control: (char) cntrl {
    size_t allocSpace,minAddr,maxAddr;
    size_t newPgSz; int fHandle;
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  // Decide about cutoff, activeSpace is the total space of active objects
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    {
    size_t i,mi,mx;
      if(lastPg==0){ // all data in one page
        // find total allocated space
        minAddr=(size_t)(pgArr[0].page);
        maxAddr=(size_t)(pgArr[0].fill);
	allocSpace=maxAddr-minAddr;
        for(i=1; i<=lastPg; i++){
            mi=(size_t)(pgArr[i].page);
            mx=(size_t)(pgArr[i].fill);
	    allocSpace=allocSpace+(mx-mi);
	    if(mi<minAddr)minAddr=mi;
	    if(mx>maxAddr)maxAddr=mx;
	}
	if(((float)(allocSpace-activeSpace))/allocSpace < co)return; // bypass
      }
    }
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  // Sort the pages by the increasing starting address.
  // Create one large page, page0, which will accomodate all active objects.
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    {
      size_t newPgSz;
      [Persist sortPages];

      newPgSz=activeSpace+pgIncr; // JS: decide about using pgIncr
      page0=calloc(newPgSz,1);
      if(page0==NULL){
	  printf("error to allocate new page in algorithmB():"); fflush(stdout);
	  printf(" newPgSz=%llu\n",(U)newPgSz); fflush(stdout);
	  exit(7);
      }
    }
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  // Pass 1: Calculate the new addresses, copy active objects into page0
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  // The objective is to set, in the old version of the data,
  // 'addr' on all active objects to the address that each objects will
  // have on the new page. Then copy each object to page0, thus creating
  // the image of the disk data, while the pointers are not swizzled yet.
  {
    size_t newAddr,obj,fil,sz,i,k,addr;

    sz=0; // just to be initialized
    newAddr=(size_t)page0+headerSz;;
    for(i=0; i<=lastPg; i++){ // go through all pages,they are sorted
	fil=(size_t)(pgArr[i].fill);
	// traverse objects within the page using the size information
	for(obj=(size_t)(pgArr[i].page)+headerSz; obj<fil; obj=obj+sz+headerSz){
	    sz=[Persist getSz: (char*)obj];
	    addr=[Persist getAddr: (char*)obj];
	    if(addr!=0){ // active object
		[Persist setAddr: (char*)obj addr: newAddr];
     memcpy((char*)(newAddr-headerSz),(char*)(obj-headerSz),sz+headerSz);
		newAddr=newAddr+sz+headerSz;
		// add obj to active[]
	    }
        }
    }
    if((newAddr-(size_t)page0-headerSz) != activeSpace){
	printf("Algorithm failure, newAddr-headerSz != activeSpace\n"); fflush(stdout);
	exit(18);
    }
  }
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  // Pass 2: Traverse all the objects in page0 (they all are active)
  // and swizzle their pointers that now lead to the OLD (!!) data.
  // The old data is unchaged and in the original positions, only the
  // 'addr' field is set which makes no difference to the application.
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  {
    char *nxtObj,**targPtr; int i,j,k,flg; size_t *mask; 
    size_t sz,fill,addr,mySz;

    fill=(size_t)page0+activeSpace;
    mySz=0; // avoid compiler warnings
    for(nxtObj=page0+headerSz; (size_t)nxtObj<fill; nxtObj=nxtObj+sz+headerSz){
	[Persist setAddr: nxtObj addr: 0];
	flg=[Persist getFlg: nxtObj];
	sz=[Persist getSz: nxtObj];
        if(flg==0)continue; // no pointers to swizzle
        if(flg==1){ // object with hidden pointer
	    mask=(size_t*)[[(id)nxtObj class] getMask];
	    if(!mask){
	        printf("failure to get the pointer mask\n"); fflush(stdout);
		exit(8);
            }
	    mySz=class_getInstanceSize([(id)nxtObj class])/ptrSz;
        }
        for(i=k=0; i<sz; i=i+ptrSz, k++){ // all ptr locations for flg=2
	    if(k>=mySz)k=0;
            if(flg==1 && mask[k]!=1)continue;
            targPtr=(char**)(nxtObj+i);
            if(*targPtr==NULL)continue;
	    addr=[Persist getAddr: (*targPtr)];
	    *targPtr=(char*)addr;
        }
     }
  }
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  // Pass 3: Write page0 to the file, and manage situation whether 
  //         the user wants to keep it, and what to do with the original data.
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  {  
     int i;

     //convert the reference to the root
     root0=(char*)[Persist getAddr: root];
     if(fileName){ // NULL is a signal not to write to the disk
         fHandle=[Persist writeHeaders: fileName];
         // copy page0 to disk
         write(fHandle,page0,activeSpace);
         close(fHandle);
     }


    if(fileName==NULL || cntrl=='C'){
        // delete all old pages
        for(i=0; i<=lastPg; i++){
	    free(pgArr[i].page);
	    pgArr[i].page=NULL;
	    pgArr[i].fill=NULL;
	    pgArr[i].pageSz=0;
        }
        pgArr[0].page=page0; // make page0 our new page[0]
        pgSz=pgArr[0].pageSz=pgSz=activeSpace+pgIncr;
        lastPg=0;
        pgArr[0].fill=page0+activeSpace;
	root=root0;
        isAddrClean=1;
    }
    else {
	// delete page0, keep everything as before
	free(page0);
        isAddrClean=0;
    }

  }
}

// Save to disk: 
// (1) General numbers and references (Header),
// (2) Table with class information (name, hidden pointer, mask).
// (3) The page with the data as one big binary block.
+(int) writeHeaders : (const char*) fileName {
    int fh,i,rec,err; size_t sz,nameSz; struct ClassRecord *cr;

    //...............................................
    fh= open(fileName,O_RDWR | O_CREAT | O_TRUNC | O_BINARY, S_IREAD | S_IWRITE);
    if(fh<0){
	printf(" cannot open file: %s in the write mode\n",fileName);
	printf("DATA NOT SAVED !!\n");
       	fflush(stdout);
	return;
    }
    //...............................................

    fileHeader.root=(size_t)root0;
    fileHeader.space=activeSpace;
    fileHeader.startAddr=(size_t)page0;
    err=0;
    rec=write(fh,&fileHeader,sizeof(struct FileHeader)); 
    if(rec!=headerSz)err=err+01;
    //...............................................
    
    for(i=0, cr=classList; cr; i++, cr=cr->next){
	sz=cr->sz;
	nameSz=strlen(cr->className)+1;
	nameSz=((nameSz+ptrSz-1)/ptrSz)*ptrSz; // round up to 4B boundary
	rec=write(fh,&sz,sizeof(size_t));
           if(rec!=sizeof(size_t))err=err|02;
	rec=write(fh,&nameSz,sizeof(size_t));
           if(rec!=sizeof(size_t))err=err|04;
	rec=write(fh,(cr->mask),sz);
           if(rec!=sz)err=err|010;
	rec=write(fh,(cr->className),nameSz);
           if(rec!=nameSz)err=err+020;
	if(err!=0){
	    printf("error in writing class=%s info, err=%o\n",cr->className,err);
	    printf("DATA NOT SAVED !!\n");
	    fflush(stdout);
	    return;
	}
    }
    //...............................................
    sz=0;
    write(fh,&sz,sizeof(size_t)); // end record for the class table
    //...............................................
    return fh;
}

+ (void) setRoot: (void*) rt {
    root=rt;
}

+ (void*) getRoot {
    return root;
}

+ (void) setAddr: (void*) p addr: (size_t) i {
    size_t *ip=(size_t*)((char*)p - 3*ptrSz);
    *ip=i;
}

+ (size_t) getAddr: (void*) p {
    size_t *ip=(size_t*)((char*)p - 3*ptrSz);
    return *ip;
}

+ (void) setSz: (char*) p size: (size_t) sz {
    size_t *ip=(size_t*)(p - 2*ptrSz);
    if(sz==0){*ip=0; return;}
    size_t k=(*ip);
    k=sz | (k & flg_mask); // include the flg 2 bits
    *ip=k;
}

+ (size_t) getSz: (char*) p {
    size_t *ip=(size_t*)(p - 2*ptrSz);
    return (*ip) & size_mask; // exclude the flg 2 bits
}

// f is an int in the range of 0-2
+ (void) setFlg: (char*) p flg: (int) f {
    size_t *ip=(size_t *)(p - 2*ptrSz);
    (*ip)=((*ip) & size_mask) | (size_t)f;
}

+ (size_t) getFlg: (char*) p {
    size_t *ip=( size_t *)(p - 2*ptrSz);
    return (*ip) & flg_mask;
}

// add record for the next class
+ (void) reportClass: (const char*) name sz: (size_t) mySz mask: (void*)msk {
    struct ClassRecord *cr;
    cr=(struct ClassRecord *)calloc(sizeof(struct ClassRecord),1);
    if(!cr)exit(10); // most unlikely to happen
    cr->className=name;
    cr->sz=mySz;
    cr->mask=(size_t *)msk;
    cr->next=classList;
    classList=cr;
}

// ----------------------------------------------------------
// Debugging print of all pages and objects
// code=i for i>=0 to print specifically page i.
// code= -1 last page,
// Enter -2 all pages,
// Enter -3 for information on pages only (useful for large data sets)
// Enter -4 all pages but disregarding hidden pointers (no pointer info)
+ (void) debugPrt: (int) code label: (char*) lab {
    size_t i,i1,i2,j,k,sz,maxObjSz,curPgSz; char *curPage,*curFill,*p;
    struct ClassRecord *cr;

    if(code>lastPg)code=lastPg;

    if(code <= -2)      {i1=0; i2=lastPg;}
    else if(code == -1) {i1=i2=lastPg;}
    else                {i1=i2=code;}

    printf("\nDEBUGGING PRINT: %s\n",lab); fflush(stdout);
    printf("=====================================\n"); fflush(stdout);
    printf("format:  (mask bit) [flag] value_or_size\n"); fflush(stdout);
    printf("flg=0 unstructured, =1 obj with ptrs, =2 array of ptrs\n\n"); fflush(stdout);
    printf("root=%llu\n",(U)[Persist getRoot]); fflush(stdout);
    printf("class records:\n"); fflush(stdout);
    maxObjSz=0;
    for(i=0, cr=classList; cr; i++, cr=cr->next){
	sz=cr->sz;
	if(sz>maxObjSz)maxObjSz=sz;
        printf("i=%llu class=%s sz=%llu mask=",(U)i,cr->className,(U)sz); fflush(stdout);
	for(k=0; k<sz/sizeof(size_t); k++){
	    printf("%llu ",(U)(cr->mask[k])); fflush(stdout);
	}
	printf("\n");
    }
    printf("\n");

    if(!pgArr)return;
    printf("\npgSz=%llu pgArrSz=%llu objCount=%llu\n",
		         (U)pgSz,(U)pgArrSz,(U)objCount);  fflush(stdout);
    for(i=i1; i<= i2; i++){
        curPage=pgArr[i].page;
	curFill=pgArr[i].fill;
	curPgSz=pgArr[i].pageSz;
	if(!curPage)break;
	printf("\nPage[%llu] page=%llu fill=%llu pageSz=%llu\n",
		(U)i,(U)curPage,(U)curFill,(U)curPgSz); fflush(stdout);
	if(code > -3 || code==(-4)){
	    [Persist debugPage: 
		curPage fill: curFill label: NULL mxObjSz: maxObjSz code: code];
	}
	printf("\n");
    }

    if(active){
	printf("\nList of active objects:\n"); fflush(stdout);
	for(k=0; ; k++){
	    p=active[k];
	    if(p==NULL)break;
	    printf("    obj=%llu addr=%llu sz=%llu\n",
		(U)p,(U)[Persist getAddr: p],(U)[Persist getSz: p]); fflush(stdout);
	}
    }
    if(useFreeObjects)[Persist debugFreeChains: 0];
}
// ----------------------------------------------------------
// Debugging print of all pages and objects
// code= -4 avoids using hiddne pointers (they may be incorrect)
// otehrwise hidden pointers may be used.
+ (void) debugPage: (char*) curPage fill: (char*) curFill 
	     label: (char*) lab mxObjSz: (size_t) maxObjSz code: (int) code {
    size_t *u,*mask,iFill; int sz,isz,imxsz,gap,bit,j,k,flg;

    if(lab){
	printf("PRINTING ONE PAGE: %s, starting at %llu\n",
		                               lab,(U)curPage);
	printf("=====================================\n");
	fflush(stdout);
    }
    gap=headerSz/ptrSz;
    iFill=((size_t)(curFill) - (size_t)curPage)/ptrSz;
    u=(size_t *)curPage;
    // u[k] will be the address of k-th pointer location, not of character
    imxsz=maxObjSz/ptrSz;
    for(k=gap,isz=0; k-gap<iFill; k=k+gap+isz){
        sz=[Persist getSz: (char*)(u+k)];
        isz=sz/ptrSz;
        flg=[Persist getFlg: (char*)(u+k)];

        if(flg == 1 && code != -4) mask=[[(id)(u+k) class] getMask];
       	else mask=NULL;

        if(k+isz > iFill){
            printf("=== end-of-page error, obj=%llu sz=%llu count=%llu\n", 
			     (U)(u[k-3]),(U)(u[k-2]),(U)(u[k-1])); fflush(stdout);
            break;
        }
        for(j= -3; j<isz; j++){
	    bit=0;
	    if(j>=0 && flg==2)bit=1;
	    if(j>=1 && flg==1 && mask != NULL)bit=mask[j];
	    if(j== -2){
	        printf("(%llu)[%llu]%llu ",(U)bit,(U)flg,(U)sz); fflush(stdout);
	    }
	    else {
#ifdef DOTS_FOR_UNSTRUCTURED_DATA
	        // avoid long prints of unstructured data
		if(j==imxsz){
		    printf(" ..... "); fflush(stdout);
		    continue;
		}
		else if(j>imxsz && j<isz-1) continue;
#endif
		if(j==0){
		    printf("  [%llu]=",(U)(u+k)); fflush(stdout);
		}
		printf("(%llu)%llu ",(U)bit,(U)(u[k+j])); fflush(stdout);
	    }
	}
        printf("\n");
    }
}
@end

