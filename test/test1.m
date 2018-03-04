#include <stdio.h>
#include <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface Book : NSObject
+ (void) start;
@end

@interface Util 
+ (void) start: (Class) klass;
@end

@implementation Book
+ (void) start { [Util start: self]; }
@end

@implementation Util
+ (void) start: (Class) klass {
    char *s=class_getName(klass);
    printf("%s\n",s);
}

int main(){
    [Book start];
    return 0;
}
