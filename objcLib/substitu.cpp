#include <stdio.h>
#include <stdlib.h>
#include <string.h>
// -----------------------------------------------------------------------
// This is a utility function which reads file fName1 and writes file fName2,
// where 
//   all occurences of '$$' are replaced by params[0]
//   all occurences of '$1' are replaced by params[1]
//   all occurences of '$2' are replaced by params[2]
//    ... and so on
// -----------------------------------------------------------------------
void substitute(char *fName1,char *fName2,char **params,int numParams,int objcRun){
static char newLine[256]; static char buff[256]; static int bSz=256;
    FILE *file1,*file2;
    int i,k,m,n,sz; char *word;
    char* num=new char[2]; char special[256];

    if(objcRun){
        strcpy(special,"ZZds."); 
        strcat(special,params[0]);
        strcat(special,"_");
        // when using this word, cut off '.' which would come after
    }
    else {
        strcpy(special,"ZZds.ZZ");
        strcat(special,params[0]);
    }

    file1=fopen(fName1,"r");
    if(!file1){
        printf("unable to open file %s for reading\n",fName1);
        return;
    }
    file2=fopen(fName2,"w");
    if(!file2){
        printf("unable to open file %s for writing\n",fName2);
        fclose(file1);
        return;
    }

    while(fgets(buff,bSz,file1)){
        for(i=k=0; buff[i]!='\0'; i++){
            if(k>=bSz-1){
                printf("error in substitute(), line over %d chars\n",bSz);
                fclose(file1); fclose(file2);
                return;
            }
                 
            if(buff[i]=='$'){
                i++;
                if(buff[i]=='$'){
		    word=params[0];
		    m= -1;
		}
                else {
                    num[0]=buff[i]; num[1]='\0'; m=atoi(num);
                    if(m==0)word=special;
                    else if(m>=1 && m<=numParams)word=params[m];
                    else {
                        printf("error: illegal string \"$%c\" in file=%s\n",
                                                              buff[i],fName1);
                        fclose(file1); fclose(file2);
                        return;
                    }
                }
                sz=strlen(word);

                for(n=0; n<sz; n++, k++){
                    if(k>=bSz-1){
                        printf("error in substitute(), line over %d chars\n",
                                                                          bSz);
                        fclose(file1); fclose(file2);
                        return;
                    }
                    newLine[k]=word[n];
                }
		if(objcRun && m==0)i++; // skip the '.' in the template
            }
            else {
                newLine[k]=buff[i];
                k++;
            }
        }
        newLine[k]='\0';
        fprintf(file2,"%s",newLine);
    }

    fclose(file1);
    fclose(file2);
}
