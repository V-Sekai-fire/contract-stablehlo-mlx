#include <stdio.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
static float *rd(const char*p,int n){FILE*f=fopen(p,"rb");float*b=malloc(n*4);fread(b,4,n,f);fclose(f);return b;}
int main(int argc,char**argv){ const char*c=argv[1]; int K=atoi(argv[2]),M=atoi(argv[3]),N=atoi(argv[4]); char p[256];
 sprintf(p,"../refOFF/%s/in0.f32",c); float*w=rd(p,K*M); sprintf(p,"../refOFF/%s/in1.f32",c); float*x=rd(p,K*N); sprintf(p,"../refOFF/%s/out.f32",c); float*o=rd(p,M*N);
 for(int variant=0;variant<6;variant++){ int bad=0;
 for(int n=0;n<N;n++)for(int m=0;m<M;m++){ const float*a=w+m*K,*b=x+n*K; float s[16]={0}; int np=K&~15;
  for(int i=0;i<np;i+=16) for(int j=0;j<16;j++) s[j]=fmaf(a[i+j],b[i+j],s[j]);
  for(int l=0;l<4;l++){s[l]+=s[8+l]; s[4+l]+=s[12+l];} for(int l=0;l<4;l++) s[l]+=s[4+l];
  float sum;
  switch(variant){case 0: sum=(s[0]+s[1])+(s[2]+s[3]); break; case 1: sum=((s[0]+s[1])+s[2])+s[3]; break; case 2: sum=(s[0]+s[2])+(s[1]+s[3]); break; case 3: sum=s[0]+(s[1]+(s[2]+s[3])); break; default: sum=(s[0]+s[1])+(s[2]+s[3]);}
  if(variant==4){ for(int i=np;i<K;i++){ sum = fmaf(a[i],b[i],sum);} }
  else if(variant==5){ double d=sum; for(int i=np;i<K;i++){ d += (double)a[i]*b[i];} sum=d;}
  else for(int i=np;i<K;i++){ volatile float q=a[i]*b[i]; sum=sum+q;}
  uint32_t g,wn; memcpy(&g,&sum,4); memcpy(&wn,&o[n*M+m],4); if(g!=wn) bad++; }
 printf("variant %d: %d bad of %d\n",variant,bad,M*N);}
}
