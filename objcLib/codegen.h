#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include "gen.h"

class Generator { // root of all the data
    int startID,objectID;
    ApplClass *derived; // used only when retrieving inheritance
    char *buff; int bufSz;
    char *name;
    char* tokens[128]; // at most 128 tokens in a 256 char text
    char *dsFileName,*libPath,*outFileName,
         *layFile,*umlFile,*srcList,*umlID;
    int umlRun,dolRun,objcRun;

    int oneLine(FILE *inpFile,int *npar1,int *npar2);
    int readDSfile();
    void readRegistry(char *libPath);
    void genIncludes(FILE *file,int type,char *libPath);
    void genInsertions(FILE *file);
    void genClasses(FILE *file);
    int genDefinitions(FILE *file);
    void searchParticipants(FILE *file,Participant *curPart);
    void genTypedefs(FILE *file);
    void genFiles(char *sourcePath,char *targetPath);
    int matchParticipants();
    PartType* findPartType(OrgType* otp,int n);
    int setInhNames(Organization *org);
    char *newString(char *str){
        char* s=new char[strlen(str)+1]; if(!s)return NULL;
        strcpy(s,str); return s;
    }
    int isBasicType(Participant *part);
    void debPrt();
    int extractInheritance(FILE *rFile);
    int extractAssociations(FILE *fp);
    int reduce(char *b);
    void eliminateComment(char *b);
    int search(char *b,int mode,FILE *rFile,char *fileName);
    char *getLast(char *b,int n);
    char *getFileName(char *b);
    void prtXMIheader(FILE *fp);
    void prtXMIclasses(FILE *fp);
    void prtXMIassociations(FILE *fp);
    void prtXMIinheritance(FILE *fp);
    void prtXMItail(FILE *fp);
    ApplClass *getOrCreateApplClass(char *s);
    char *i2s(int i,char *s,int sz);
    void ptrListFirstLines(FILE *file);
public:
    ZZ_Generator ZZds;
    Generator(int umlR,int dolR,int objcR,char **argv);
    int generate();
    int genUmlFile();
    OrgType *getOrgType(char *s,int full);
    int getObjectID(){objectID++; return objectID;}
};

class Organization {
    int id;
public:
    ZZ_Organization ZZds;
    Organization(){};
    Organization(Generator *gen){id=gen->getObjectID();}
    int getID(){return id;}
};

class OrgType  {
    int fullRecord;    // 0 or 1
    char umlCode[8];   // e.g. "b1-*"
public:
    ZZ_OrgType ZZds;
    OrgType(int full){fullRecord=full;};
    int isFull(){return fullRecord;}
    void setFull(){fullRecord=1;}
    int isBidirect(){char c=umlCode[0]; if(c=='B'||c=='b')return 1; return 0;}
    void setCode(char *p){strcpy(umlCode,p);}
    char *getCode(){return umlCode;}
};

class Participant {
    int used; // 0=notUsed, 1=used for ZZS, 2= used also by ptrList..
    int index;
    int id;
public:
    ZZ_Participant ZZds;
    Participant(){used=index=id=0;}
    Participant(int i,ApplClass *apClass,Organization *org,Generator *gen);
    void setUsed(int i){used=i;}
    int isUsed(){return used;}
    int getIndex(){return index;}
    int getMultiplicity();
};

class PartType {
    int index;
    int refOnly;
    int multiplicity; // -1 for * 
    int navigable; // 1=yes, 0=no
public:
    ZZ_PartType ZZds;
    PartType(int i, int ref){index=i; refOnly=ref;}
    int getIndex(){return index;}
    int isRefOnly(){return refOnly;}
    void setMult(unsigned char c){
         char s[2]; s[0]=c; s[1]='\0';
         if(c=='*')multiplicity= -1;
         else multiplicity= atoi(s);
    }
    char getMult(){return multiplicity;}
};

class FixedType {
public:
    ZZ_FixedType ZZds;
    FixedType(){}
};

class Iterator {
public:
    ZZ_Iterator ZZds;
};

class ApplClass {
    int id;
    int ci; // 1= class, 0= interface (unused, in C++ always 'class')
    int count; // temporary count for some algorithms
public:
    ZZ_ApplClass ZZds;
    ApplClass(char *s);
    int getID(){return id;}
    void setID(Generator *gen){id=gen->getObjectID();}
    int classOrInterface(){return ci;}
    void setClassOrInterface(int cORi){ci=cORi;}
    void setCount(int i){count=i;}
    int getCount(){return count;}
    void incrCount(){count++;}
};

class ClassLink {
    int relation; // 0=inheritance, 1=interface
public:
    ZZ_ClassLink ZZds;
    ClassLink(){relation=0;}
    ClassLink(int rel){relation=rel;}
    int getRelation(){return relation;}
};
















