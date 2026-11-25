#define COBJMACROS
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <stdio.h>
static void dump(IMFSourceReader*r,DWORD s,const char*n){IMFMediaType*t=0;HRESULT h=IMFSourceReader_GetNativeMediaType(r,s,0,&t);if(SUCCEEDED(h)){GUID g;IMFMediaType_GetGUID(t,&MF_MT_SUBTYPE,&g);printf("%s native subtype %08lx\n",n,g.Data1);IMFMediaType_Release(t);}else printf("%s native type hr=%08lx\n",n,h);}
int main(int c,char**v){
 HRESULT hr=CoInitializeEx(0,COINIT_MULTITHREADED);hr=MFStartup(MF_VERSION,0);printf("MFStartup %08lx\n",hr);
 IMFSourceReader*r=0;hr=MFCreateSourceReaderFromURL(L"C:\\clip10.mp4",0,&r);printf("CreateSourceReader %08lx\n",hr);if(FAILED(hr))return 1;
 dump(r,MF_SOURCE_READER_FIRST_VIDEO_STREAM,"video");dump(r,MF_SOURCE_READER_FIRST_AUDIO_STREAM,"audio");
 IMFMediaType*t;MFCreateMediaType(&t);IMFMediaType_SetGUID(t,&MF_MT_MAJOR_TYPE,&MFMediaType_Video);IMFMediaType_SetGUID(t,&MF_MT_SUBTYPE,&MFVideoFormat_RGB32);
 hr=IMFSourceReader_SetCurrentMediaType(r,MF_SOURCE_READER_FIRST_VIDEO_STREAM,0,t);printf("set video RGB32 %08lx\n",hr);
 int got=0;for(int i=0;i<30;i++){DWORD si,fl;LONGLONG ts;IMFSample*s=0;hr=IMFSourceReader_ReadSample(r,MF_SOURCE_READER_FIRST_VIDEO_STREAM,0,&si,&fl,&ts,&s);
  if(FAILED(hr)||fl&MF_SOURCE_READERF_ENDOFSTREAM||!s){printf("read %d hr=%08lx flags=%lx\n",i,hr,fl);break;}
  IMFMediaBuffer*b;IMFSample_ConvertToContiguousBuffer(s,&b);DWORD len=0;IMFMediaBuffer_GetCurrentLength(b,&len);if(i<3||i==29)printf("frame %d t=%lldms bytes=%lu\n",i,ts/10000,len);got++;IMFMediaBuffer_Release(b);IMFSample_Release(s);}
 printf("frames decoded: %d\n",got);return got>0?0:2;}
