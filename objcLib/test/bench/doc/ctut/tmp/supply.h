
// -------- data structure DOUBLY LINKED RING ---------------
// EQUIVALENT OF:
// template <class Node> class supply_Ring2
// ----------------------------------------------------------
// Ring2 could be derived from Ring2 through inheritance, but
//  (a) The complex functions (sort, remove, merge) are different anyway,
//  (b) we want to minimize the nubmer of classes which will be code generated.
// For these two reasons, Ring2 is coded as a base class.
// ----------------------------------------------------------
#ifndef ZZ_supply_RING2_INCLUDED
#define ZZ_supply_RING2_INCLUDED

class PartType;
typedef int (*ZZsortFun)(const void *, const void *);

// ----------------------------------------------------------
// description of the cooperating classes
// ----------------------------------------------------------
class supply_Ring2Element {
public:
    PartType *next;
    PartType *prev;
    supply_Ring2Element(){ next=prev=NULL; }
};

class supply_Ring2 {

    static int debugFun(PartType *tail);
public:
    // standard interface
    static PartType* addHead(PartType *tail, PartType *c); // returns new tail
    static PartType* addTail(PartType *tail, PartType *c); // returns new tail
    static PartType* append(PartType *tail,PartType *c1, PartType *c2); // returns new tail
    static void insert(PartType *c1, PartType *c2); // insert c1 before c2
    static PartType* remove(PartType *tail, PartType *c);  // returns new tail, NULL when empty
    static PartType* const next(PartType *p, PartType *c); // returns NULL when p is the tail
    static PartType* const prev(PartType *p, PartType *c); // returns NULL when p is the head
    static PartType* const fwd(PartType *c); // unprotected raw ring pointer
    static PartType* const bwd(PartType *c); // unprotected raw ring pointer
    static PartType* sort(ZZsortFun cmpFun, PartType *tail); // returns the new tail
    static void merge(PartType *s,PartType *t);

    // historical DOL compatible interface
    static PartType* del(PartType *tail, PartType *c) { return remove(tail,c); }
    static PartType* add(PartType *tail, PartType *c) { return addHead(tail,c); }
    static void ins(PartType *c1, PartType *c2) { insert(c1,c2); }
    
};

class supply_Ring2Iterator {
    PartType *tail; // NULL when loop finished
    PartType *nxt;  // NULL when starting a new loop
    int dir;  // 0=from head, 1=from tail
public:
    // standard interface:          for(p=it.fromHead(x); p; p=it.next()){...}
    //                              for(p=it.fromTail(x); p; p=it.next()){...}
    supply_Ring2Iterator(){tail=nxt=NULL; dir=0;}
    virtual PartType* fromHead(PartType *p);
    virtual PartType* fromTail(PartType *p);
    virtual PartType* const next();

    // historical DOL interface:    it.start(x); for(p= ++it; p; p= ++it){...}
    //                              it.start(x); for(p= --it; p; p= --it){...}
    virtual void start(PartType *p);
    virtual PartType* const operator++();
    virtual PartType* const operator--();
    supply_Ring2Iterator(PartType *p){start(p);}
};
    
#endif // ZZ_supply_RING2_INCLUDED
