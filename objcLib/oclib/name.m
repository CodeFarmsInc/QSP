#include <string.h>
@class $1;

@implementation $$_Name
+ (void) add: ($1*) p cString: (char*) c
{
    char* s=p->$0.name;
    if(s){
        printf("$$:add() error: object=%llu has already a name\n",(U)p); return;
    }
    p->$0.name=c;
}

+ (void) addNew: ($1*) p cString: (const char*) c
{
    char *s;
    if(!c){
        printf("$$:addNew() given a NULL name\n"); return;
    }
    s=[Persist palloc: strlen(c)+1];
    if(!s){
        printf("$$:addNew() error: problem to allocate string=%s\n",c); return;
    }
    strcpy(s,c);
    p->$0.name=s;
}

+ (char*) get: ($1*) p{ return p->$0.name;}

+ (int) compare: ($1*) p1 second: ($1*) p2
{
    return strcmp(p1->$0.name, p2->$0.name);
}

+ (char*) remove: ($1*) p1
{
    char* s=p1->$0.name; p1->$0.name=NULL; return s;
}
@end