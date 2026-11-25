#include <windows.h>
#include <stdio.h>
#include <string.h>
typedef HRESULT (*QueryFn)(const GUID*,const GUID*,void**);
static const GUID CLS={0x704c3f58,0xe629,0x4cc2,{0xb1,0x97,0x30,0x51,0x1b,0x99,0x6f,0xe2}};
static const GUID IID_={0x1bfff3af,0xf14a,0x40a3,{0x8e,0x35,0x9a,0xda,0x90,0x65,0x93,0xf9}};
typedef struct{const char*name;unsigned size;}BI; typedef struct{BI info;unsigned char*data;}BL;
typedef struct{const char*name;const char*display;unsigned blobs;unsigned long long total;long long mtime;unsigned char sync;}CI;
static int bcb(const BI*i,void*c){printf("  blob '%s' %u bytes\n",i->name,i->size);return 1;}
static int ccb(const CI*i,void*c){printf("  container '%s' display '%s' blobs %u total %llu mtime %lld\n",i->name,i->display,i->blobs,i->total,i->mtime);return 1;}
#define V(n) ((void**)(*(void***)obj))[n]
int main(int c,char**v){
 const char*mode=c>1?v[1]:"write"; HMODULE m=LoadLibraryW(L"xgameruntime.dll"); if(!m){puts("no dll");return 1;}
 QueryFn q=(QueryFn)GetProcAddress(m,"QueryApiImpl"); void*obj=0; HRESULT hr=q(&CLS,&IID_,&obj); printf("QueryApiImpl %08lx obj %p\n",hr,obj); if(hr)return 1;
 void*prov=0,*cont=0,*upd=0;
 hr=((HRESULT(*)(void*,void*,const char*,int,void**))V(3))(obj,0,"cfg",0,&prov); printf("InitializeProvider %08lx\n",hr);
 hr=((HRESULT(*)(void*,void*,const char*,void**))V(16))(obj,prov,"slot1/main",&cont); printf("CreateContainer %08lx\n",hr);
 if(!strcmp(mode,"write")){
  hr=((HRESULT(*)(void*,void*,const char*,void**))V(23))(obj,cont,"My Save",&upd); printf("CreateUpdate %08lx\n",hr);
  hr=((HRESULT(*)(void*,void*,const char*,const void*,size_t))V(25))(obj,upd,"world","hello world",11); printf("BlobWrite world %08lx\n",hr);
  hr=((HRESULT(*)(void*,void*,const char*,const void*,size_t))V(25))(obj,upd,"player.dat","P1:chapter3",11); printf("BlobWrite player %08lx\n",hr);
  hr=((HRESULT(*)(void*,void*))V(27))(obj,upd); printf("SubmitUpdate %08lx\n",hr);
  ((void(*)(void*,void*))V(24))(obj,upd);
 }
 puts("blobs:"); hr=((HRESULT(*)(void*,void*,void*,void*))V(18))(obj,cont,0,(void*)bcb); printf("EnumerateBlobInfo %08lx\n",hr);
 const char*names[2]={"world","player.dat"}; unsigned cnt=2; static unsigned char buf[4096];
 hr=((HRESULT(*)(void*,void*,const char**,unsigned*,size_t,void*))V(20))(obj,cont,names,&cnt,sizeof buf,buf); printf("ReadBlobData %08lx count %u\n",hr,cnt);
 if(!hr){BL*b=(BL*)buf;for(unsigned i=0;i<cnt;i++)printf("  read '%s' (%u) = %.*s\n",b[i].info.name,b[i].info.size,(int)b[i].info.size,b[i].data);}
 const char*miss[1]={"nope"}; cnt=1; hr=((HRESULT(*)(void*,void*,const char**,unsigned*,size_t,void*))V(20))(obj,cont,miss,&cnt,sizeof buf,buf); printf("ReadBlobData missing -> %08lx (expect 80830008)\n",hr);
 puts("containers:"); hr=((HRESULT(*)(void*,void*,void*,void*))V(14))(obj,prov,0,(void*)ccb); printf("EnumerateContainerInfo %08lx\n",hr);
 if(!strcmp(mode,"delete")){hr=((HRESULT(*)(void*,void*,const char*))V(10))(obj,prov,"slot1/main"); printf("DeleteContainer %08lx\n",hr);}
 ((void(*)(void*,void*))V(17))(obj,cont); ((void(*)(void*,void*))V(6))(obj,prov); puts("done"); return 0;}
