// ----------------------------------------------------------
//                    1XtoX<Relation,Entity>
// ----------------------------------------------------------
// This data organization is not intended for direct use. It is the root
// organization of ManyToMany for 2,3 or more participating classes.
// Note that 1XtoX is derived from Aggregate2<>, but the 
// parameters are reversed.
//                                    Jiri Soukup, July 14, 2005
// ----------------------------------------------------------

// ----------------------------------------------------------
#ifndef ZZ_$$_1XTOX_INCLUDED
#define ZZ_$$_1XTOX_INCLUDED

@class $1;
@class $2;

// description of the cooperating classes
#define $$_1XtoXRelation \
    $$_Aggregate2Child 

#define $$_1XtoXEntity1 \
    $$_Aggregate2Parent
// .....................................
#define $$_1XtoXRelation_ptrList \
    $$_Aggregate2Child_ptrList 

#define $$_1XtoXEntity1_ptrList \
    $$_Aggregate2Parent_ptrList

// ----------------------------------------------------------

@interface $$_1XtoX : $$_Aggregate2 
+ (void) add: ($1*) r ent: ($2*) e;
+ (void) remove: ($1*) r;
+ ($2*) entity1: ($1*) r;
+ ($1*) next1: ($1*) r; // returns NULL when s is the tail
+ ($1*) prev1: ($1*) r; // returns NULL when s is the head
@end

@interface $$_1XtoXIterator : $$_Aggregate2Iterator 
       // standard interface: for(r=[it from1: e]; r; r=[it next1]){...}
- (id) init;
- ($1*) from1: ($2*) e;
- ($1*) next1;
@end

#endif // ZZ_$$_1XTOX_INCLUDED
