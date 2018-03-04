// ----------------------------------------------------------
//                    2XtoX<Relation,Entity1,Entity2>
//
// This is the most frequently used Many-To-Many relation between
// two entity types. For each recorded relation there is an Relation object.
// ----------------------------------------------------------
// By repeating this code with minor modifications, it is easy
// to derive higher order many-to-many relations:
//    from 2XtoX to derive 2XtoX (this code)
//    from 2XtoX to derive 3XtoX
//    from 3XtoX to derive 4XtoX
//    ... and so on ...
//                                    Jiri Soukup, July 14, 2005
// ----------------------------------------------------------

// ----------------------------------------------------------
#ifndef ZZ_$$_2XTOX_INCLUDED
#define ZZ_$$_2XTOX_INCLUDED

class $1;
class $2;
class $3;

// description of the cooperating classes
class $$_2XtoXRelation : public $$_1XtoXRelation {
public:
    $1 *next2;
    $1 *prev2;
    $3 *parent2;
    $$_2XtoXRelation() : $$_1XtoXRelation(){ next2=prev2=NULL; parent2=NULL;}
};

class $$_2XtoXEntity1 : public $$_1XtoXEntity1 {
public:
    $$_2XtoXEntity1() : $$_1XtoXEntity1(){ }
};

class $$_2XtoXEntity2 {
public:
    $1 *tail2;
    $$_2XtoXEntity2(){tail2=NULL;}
};


// ----------------------------------------------------------

class $$_2XtoX : public $$_1XtoX {

public:
    static void add($1 *r, $2 *e1,$3 *e2); // equivalent of addTail()
    static void remove($1 *r);

    static $2* const entity1($1 *r){return $$_1XtoX::entity1(r);}
    static $1* const next1($1 *r)  {return $$_1XtoX::next1(r);}
    static $1* const prev1($1 *r)  {return $$_1XtoX::prev1(r);}

    static $3* const entity2($1 *r);
    static $1* const next2($1 *r);   // returns NULL when s is the tail
    static $1* const prev2($1 *r);   // returns NULL when s is the head
};

class $$_2XtoXIterator : public $$_1XtoXIterator {
    // standard interface:          for(r=it.from1(e1); r; r=it.next1()){...}
    // standard interface:          for(r=it.from2(e2); r; r=it.next2()){...}
    $1 *tail2;
    $1 *nxt2;
public:
    $1* from1($2 *e) {return $$_1XtoXIterator::from1(e);}
    $1* const next1(){return $$_1XtoXIterator::next1();}

    $1* from2($3 *e);
    $1* const next2();
};

#endif // ZZ_$$_2XTOX_INCLUDED
