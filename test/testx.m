#include <stdio.h>
#include <Foundation/Foundation.h>

@interface K : NSObject
{
 @public
  int k;
}
- (void) prt ;
- (void) prt0 ;
@end

@implementation K
- (void) prt { NSLog(@"obj=%@ k=%d\n",self,k); }
- (void) prt0 { NSLog(@"obj0=%@",self); }
@end

@interface M : NSObject
{
 @public
  int m;
}
- (void) prt ;
- (void) prtK : (Class) klass ;
@end

@implementation M
- (void) prt { NSLog(@"obj=%@ m=%d\n",self,m); }
- (void) prtK : (Class) klass {
    id k = [klass alloc];
    [k prt0];
}
@end

int main(){
   M *m=[M alloc]; 
   [m prt];
   Class klass = [K class];
   [m prtK : klass];
   return 0;
}
