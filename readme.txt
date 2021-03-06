--------------------------------------------------------------------------
   Persistence based on QSP(Quasi-Single-Page) algorithm and implemented
     in Objetive-C, plus the InCode library converted to Objective-C.
--------------------------------------------------------------------------
                  Copyright (c) Code Farms Inc. 2013

This directory provides the QSP (Quasi-Single-Page) persistence for Objective-C.
The entire implementation has only two source files, Persist.h and Persist.m.
Application can simply copy these files and compile with them.

The persistence is simple and light, and is completely contained in files 
Persist.h and Persist.m. This directory provides two versions of these files:
  c:\qst\persistFast.* files are a slightly faster version using long macros,
  c:\qst\persistElegant.* use shorter macros and function calls, and are much
                          easier to debug. 
As a default, files Persist.* are just a copy of PersistFast.*.

Subdirectory 'objcLib' is the Objective-C version of the InCode library,
with the code generator codegen.cpp, which is applicable to both C++ and
Objective-C, but it is written in C++.
  tt.bat compiles the code generator,
  rr.bat runs in on a small test example.

Subdirectory 'objcLib\lib' contains special templates for the data structures
from the InCode library and,
at the time of this writing, is identical with InCode\lib

Subdirectory 'objcLib\oclib' contains the same templates converted to
Objective-C but, at the time of this
writing, not all templates have been converted.
If the data structure shows as *.m (for example aggreg2.m), it has been
converted. If it shows as *.cpp (for example lnkarray.cpp), it has NOT been
converted to Objective-C yet.

Subdirectory 'test' is an example of how to use this library.
It is the Objective-C version of the benchmark from the book
Jiri Soukup: Serialization and Persistent Objects. 
On how to run this test, see readme.txt in that directory.
                                                   
                                   Jiri Soukup, November 2, 2013
