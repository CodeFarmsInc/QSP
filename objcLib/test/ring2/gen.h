#ifndef ZZ_CODEGEN_INCLUDE
#define ZZ_CODEGEN_INCLUDE

#include "..\..\lib/general.h"

class A;

#include "tmp/ring1.h"
#include "tmp/ring2.h"

// -----------------------------------------------
typedef class ring1_Ring2 ring1;
typedef class ring2_Ring2 ring2;
// -----------------------------------------------


class ZZ_A {
public:
    ring1_Ring2Element ZZring1;
    ring2_Ring2Element ZZring2;
};

typedef ring1_Ring2Iterator ring1_Iterator;
typedef ring2_Ring2Iterator ring2_Iterator;

#endif // ZZ_CODEGEN_INCLUDE
