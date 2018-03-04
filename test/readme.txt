------------------------------------------------------------------------
Objective-C benchmark which uses QSP persistence with InCode library. 
------------------------------------------------------------------------
               Copyright (c) Code Farms Inc 2013

File gg.bat assumes that the qsp library has been installed under 
the same directory as this test. If your installation is different, 
it is easy to modify this short file.

The persistence is simple and light, and is completely contained in files 
Persist.h and Persist.m which gg.bat copies over.

The Objecteive-C version of the InCode library is in qst\objcLib\oclib.
Note that only classes required for this benchmark have been converted 
to Objective-C, only 6 out of 22 classes that are currently in
the C++ version which is in qsp\objcLib\lib

gg.bat copies over Persist.h and Persist.m. then runs
the InCode code generator, codegen, which creates gen.h and gen.m in this
directory. It also creates expanded templates of the required data structures
and stores them in directory tmp.

tt.bat compiles the benchmark.

rr1.bat is the first run which creates the data and stores it on disk.

rr2.bat reads the data from the disk, removes some, and stores is again.

In files rr1.bat and rr2.bat, parameter -b 1000000 defines the size of
the problem, the number of books - in this case 1,000,000 books. If you want
to test with smaller size, change this parameter. 

The data is saved into files *.dat, which can be quite large
(0.4GB for 1,000,000 books).

clean.bat cleans the data files, object and executable files, and the expanded
templates in ./tmp
------------------------------------------------------------------------
                                      Jiri Soukup, November 2, 2013
