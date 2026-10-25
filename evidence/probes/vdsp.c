#include <Accelerate/Accelerate.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
static uint32_t st=12345; static float rnd(){ st=st*1664525u+1013904223u; return ((st>>8)*(1.0f/8388608.0f)-1.0f)*3.0f; }
// candidate: A accumulators of width 4 (A*4 lanes), per-lane fadd, then tree/sequential reduce
static float cand_sum(const float*x,int n,int A,int tree,int fused_sq, int sq){
  float acc[64]={0}; int L=A*4; int np=n/L*L;
  for(int i=0;i<np;i+=L) for(int j=0;j<L;j++){ float v=x[i+j]; if(sq){ if(fused_sq) acc[j]=fmaf(v,v,acc[j]); else {volatile float p=v*v; acc[j]+=p;} } else acc[j]+=v; }
  // reduce vectors pairwise
  int w=L;
  if(tree){ while(w>4){ w/=2; for(int j=0;j<w;j++) acc[j]+=acc[j+w]; } }
  else { for(int k=1;k<A;k++) for(int l=0;l<4;l++) acc[l]+=acc[k*4+l]; }
  float s = tree==2 ? ((acc[0]+acc[2])+(acc[1]+acc[3])) : ((acc[0]+acc[1])+(acc[2]+acc[3]));
  for(int i=np;i<n;i++){ float v=x[i]; if(sq){ if(fused_sq) s=fmaf(v,v,s); else {volatile float p=v*v; s+=p;} } else s+=v; }
  return s;
}
int main(){ int n=1024; float x[4096];
 for(int A=1;A<=16;A*=2) for(int tree=0;tree<3;tree++){ int bad=0, badq[2]={0,0};
  st=12345;
  for(int t=0;t<300;t++){ for(int i=0;i<n;i++) x[i]=rnd();
   float s; vDSP_sve(x,1,&s,n); if(cand_sum(x,n,A,tree,0,0)!=s) bad++;
   float q; vDSP_measqv(x,1,&q,n);
   for(int f=0;f<2;f++){ float c=cand_sum(x,n,A,tree,f,1)/ (float)n; if(c!=q) badq[f]++; }
  }
  printf("A=%d tree=%d: sve bad %d/300, measqv bad unfused %d fused %d\n",A,tree,bad,badq[0],badq[1]);
 }
}
