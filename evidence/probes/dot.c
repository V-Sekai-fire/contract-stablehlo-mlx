#include <stdio.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
static float *rd(const char*p,int n){FILE*f=fopen(p,"rb");float*b=malloc(n*4);fread(b,4,n,f);fclose(f);return b;}
int main(){ int K=37,M=5,N=3; float*w=rd("../refOFF/mul_mat_small/in0.f32",K*M),*x=rd("../refOFF/mul_mat_small/in1.f32",K*N),*o=rd("../refOFF/mul_mat_small/out.f32",M*N);
 for(int variant=0;variant<4;variant++){ int bad=0;
 for(int n=0;n<N;n++)for(int m=0;m<M;m++){ const float*a=w+m*K,*b=x+n*K; float s[16]={0}; int np=K&~15;
  for(int i=0;i<np;i+=16) for(int j=0;j<16;j++) s[j]=fmaf(a[i+j],b[i+j],s[j]);
  for(int l=0;l<4;l++){s[l]+=s[8+l]; s[4+l]+=s[12+l];} for(int l=0;l<4;l++) s[l]+=s[4+l];
  float sum = (variant&1)? ((s[0]+s[1])+(s[2]+s[3])) : (((s[0]+s[2])+(s[1]+s[3])));
  for(int i=np;i<K;i++){ if(variant&2) { volatile float p=a[i]*b[i]; sum=sum+p;} else sum=fmaf(a[i],b[i],sum);}
  uint32_t g,wn; memcpy(&g,&sum,4); memcpy(&wn,&o[n*M+m],4); if(g!=wn) bad++; }
 printf("variant %d (pair01=%d, mul+add tail=%d): %d bad\n",variant,variant&1,(variant>>1)&1,bad);}
}
