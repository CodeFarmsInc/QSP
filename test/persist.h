#ifndef PERSIST_H_DEFINED
#define PERSIST_H_DEFINED

// Uncomment the next line for APPLE, may not needed for LINUX or Windows
#import <objc/runtime.h>

#define U unsigned long long)(size_t

#ifdef XML_SERIALIZE
void writeSingleObject(id obj){
    // archiveAToXmlPlist(obj,@"data.xml");
    // Can't this be more general? Do I need one archive..() for every class?
    printf("serialized class=%s addr=%u\n",class_getName([obj class]),obj);
}
#endif

#ifdef ONE_PAGE_STORAGE
#ifndef XML_SERIALIZE
// will never be executed, but it is needed to compile
void writeSingleObject(id obj){
}

#endif
#endif

@interface PersistObject : NSObject 
- (id) ptrList;
+ (void) start;
+ (void*) getMask; 
+ (id) alloc ; 
+ (id) allocArr: (size_t) sz; 
@end

typedef struct persist_params {
     void* mask;
     size_t mySz;
     size_t count;
     int flg;
} persist_params;

@interface Persist : NSObject
// This method starts the Utility which controls allocation, serialization,
// and persistent memory pages. If you call it with totalSpace=0, 
// the program will gradually adjust to the size of the data automatically.
// If you provide even a rough estimate of totalSpace, it will slightly improve
// the performance until the first call to [Util save]. After this call,
// the program takes over the control of pages and their sizes.
// When estimating totalSpace of your data, consider not only the sizes
// f objects, but add also 12B for every allocated object or array.
+ (void) start: (size_t) totalSize;
+ (void*) palloc: (size_t) sz ;  // sz=size in bytes
+ (void*) allocPtrArr: (size_t) sz ;  // sz=number of pointers
+ (void) save: (const char*) fileName method: (char) c; // c=  'X'/'B'/'P'/'C'
+ (int) addPage: (size_t) sz ; // returns page index for the new object
+ (void) enlargePgArr ;
+ (void) algorithmA: (int) genOutput; // 1 serialization, 0 finds active objects
+ (void) sortPages;
+ (void) algorithmB: (const char*) fileName pageIncr: (size_t) pgIncr cutoff: (float) co control: (char) cntrl;
+ (int) writeHeaders: (const char*) fileName;
+ (void) debugPrt: (int) code label: (char*) lab ;
+ (void) debugPage: (char*) curPage fill: (char*) curFill label: (char*) lab
	                           mxObjSz: (size_t) maxObjSz code: (int) code;
+ (void) setRoot: (void*) rt;
+ (void*) getRoot;
+ (void) setAddr: (void*) p addr: (size_t) i;
+ (size_t) getAddr: (void*) p;
+ (void) setSz: (char*) p size: (size_t) sz;
+ (size_t) getSz: (char*) p;
+ (void) setFlg: (char*) p flg: (int) f;
+ (size_t) getFlg: (char*) p;
+ (void) reportClass: (const char*) name sz: (size_t) mySz mask: (void*)msk;
+ (void) cleanAddr;
+ (void) cleanup;
+ (void) open: (char*) fileName pgIncr: (size_t) incr;
+ (struct ClassRecord*) readHeaders: (int) fh;
+ (size_t *) hiddenPtrTable: (struct ClassRecord *) oldClassList
			      base: (size_t *) pBase slot: (size_t *) pSlot;
+ (void) outsideStart:  (Class) klass params: (persist_params*) data;
+ (id) outsideAlloc:    (Class) klass params: (persist_params*) data;
+ (id) outsideAllocArr: (Class)klass params: (persist_params*) data size: (size_t) s;
+ (void) createMask:    (Class) klass params: (persist_params*) data;
+ (void) pfree: (void*) p; // store the given space in the free storage, 
                           // each space knows its size, no need to supply it
+ (void*) getFree: (size_t) sz; // get a chunk from free storage, NULL=failed
+ (void) startFree; // create structures for the free storage
+ (void) manageFreeObjects: (int) i; // 1=free lists, 0=only when saving
+ (int) findFree: (size_t) sz purpose: (int) z;
+ (void) debugFreeChains: (int) printEmpty;
+ (void) debugChain: (void*) head;
@end


#define ONE (void*)1
#define PTR(P) (P)=(void*)1

#define PersistInterface \
 - (id) ptrList;  \
+ (void*) getMask; \
+ (void) start; \
+ (id) alloc ; \
+ (id) allocArr: (size_t) sz


#define PersistImplementation \
static struct persist_params params= { nil, 0, 0, 0}; \
+ (void*) getMask {return params.mask;} \
+ (void) start{ [Persist outsideStart: self params: &params];}  \
+ (id) alloc{ return [Persist outsideAlloc: self params: &params];}  \
+ (id) allocArr: (size_t) sz { return \
       [Persist outsideAllocArr: self params: &params size: (size_t) sz]; \
    }

#endif // PERSIST_H_DEFINED
