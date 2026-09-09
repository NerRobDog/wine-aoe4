/* Experimental conservative relocation of straight-line generated fragments.
 *
 * NerRobDog 2026-09-09: near conditional branches (0F 8x rel32) that leave the block are
 * relocatable too: the block continues on the fall-through path and the rel32 is
 * patched like any other relocation. Only the 6-byte form is accepted so the cached
 * copy keeps the original byte layout (aoe_cache_logical_pc maps shadow<->original by
 * offset). Short Jcc (70..7F rel8), calls, loops, jumps into the block, prefixed
 * branches and more than 8 relocations are still refused. */
#include <stdint.h>
#include <string.h>
#include <limits.h>
#include "aoe_hde_impl.h"
#define AOE_FRAGMENT_MAX 40
struct aoe_fragment_key { uint8_t code[AOE_FRAGMENT_MAX], len, count, offsets[8], ends[8]; uint64_t targets[8]; };
static int aoe_plain_instruction(const hde64s *h)
{
 unsigned op=h->opcode;
 if(h->p_rep||h->p_67||h->p_lock)return 0;
 if(op==0x0f)return (h->opcode2>=0x40&&h->opcode2<=0x4f)||(h->opcode2>=0x90&&h->opcode2<=0x9f)||h->opcode2==0xaf||h->opcode2==0xb6||h->opcode2==0xb7||h->opcode2==0xbe||h->opcode2==0xbf;
 if((op>=0x50&&op<=0x5f)||(op>=0xb0&&op<=0xbf)||op==0x90||op==0x98||op==0x99)return 1;
 if(op<=0x3d && (op&7)<=5)return 1;
 switch(op){case 0x63:case 0x68:case 0x69:case 0x6a:case 0x6b:case 0x80:case 0x81:case 0x83:case 0x84:case 0x85:case 0x86:case 0x87:case 0x88:case 0x89:case 0x8a:case 0x8b:case 0x8d:case 0x8f:case 0xc0:case 0xc1:case 0xc6:case 0xc7:case 0xd0:case 0xd1:case 0xd2:case 0xd3:case 0xf6:case 0xf7:case 0xfe:return 1;case 0xff:return h->modrm_reg<=1;default:return 0;}
}
/* Near Jcc 0F 80..8F rel32 only (layout-preserving); short Jcc is left to the generic refusal. */
static int aoe_near_jcc(const hde64s *h){return h->opcode==0x0f&&h->opcode2>=0x80&&h->opcode2<=0x8f;}
static int aoe_fragment_key(const uint8_t *source,unsigned available,uint64_t pc,struct aoe_fragment_key *k)
{
 unsigned offset=0,out=0,steps;memset(k,0,sizeof(*k));
 for(steps=0;steps<16 && offset<available;steps++){
  uint8_t scratch[32]={0};hde64s h;unsigned imm=0,disp;uint64_t target;
  memcpy(scratch,source+offset,available-offset<16?available-offset:16);hde64_disasm(scratch,&h);
  if(!h.len||h.len>available-offset||(h.flags&F_ERROR)||h.p_67||h.p_rep||h.p_lock)return 0;
  if(h.opcode==0xe9||h.opcode==0xeb){
   if(h.p_66||h.p_seg||h.rex||k->count==8||out+5>AOE_FRAGMENT_MAX)return 0;
   target=pc+offset+h.len+(h.opcode==0xe9?(int64_t)(int32_t)h.imm.imm32:(int64_t)(int8_t)h.imm.imm8);
   /* Avoid branches into this block; they need a complete control-flow map. */
   if(target>=pc&&target<pc+available)return 0;
   k->code[out]=0xe9;k->offsets[k->count]=out+1;k->ends[k->count]=out+5;k->targets[k->count++]=target;k->len=out+5;return 1;
  }
  if(aoe_near_jcc(&h)){
   /* conditional branch leaving the block: relocate rel32, block continues on the fall-through path */
   if(h.p_66||h.p_seg||h.rex||h.len!=6||k->count==8||out+6>AOE_FRAGMENT_MAX)return 0;
   target=pc+offset+h.len+(int64_t)(int32_t)h.imm.imm32;
   if(target>=pc&&target<pc+available)return 0;
   k->code[out]=0x0f;k->code[out+1]=h.opcode2;k->offsets[k->count]=out+2;k->ends[k->count]=out+6;k->targets[k->count++]=target;
   out+=6;offset+=6;continue;
  }
  if(out+h.len>AOE_FRAGMENT_MAX)return 0;
  memcpy(k->code+out,source+offset,h.len);
  if(h.opcode==0xc3||h.opcode==0xc2){if(h.p_66||h.p_seg||h.rex)return 0;k->len=out+h.len;return 1;}
  if((h.flags&F_RELATIVE)||!aoe_plain_instruction(&h))return 0;
  if((h.flags&F_MODRM)&&h.modrm_mod==0&&h.modrm_rm==5){
   if(h.p_seg||!(h.flags&F_DISP32)||k->count==8)return 0;
   if(h.flags&F_IMM8)imm+=1;if(h.flags&F_IMM16)imm+=2;if(h.flags&F_IMM32)imm+=4;if(h.flags&F_IMM64)imm+=8;
   if(h.len<imm+4)return 0;disp=out+h.len-imm-4;
   target=pc+offset+h.len+(int64_t)(int32_t)h.disp.disp32;
   memset(k->code+disp,0,4);k->offsets[k->count]=disp;k->ends[k->count]=out+h.len;k->targets[k->count++]=target;
  }
  out+=h.len;offset+=h.len;
 }
 return 0;
}
static int aoe_fragment_emit(const struct aoe_fragment_key *k,uint64_t pc,uint8_t output[AOE_FRAGMENT_MAX])
{
 unsigned i;memcpy(output,k->code,AOE_FRAGMENT_MAX);
 for(i=0;i<k->count;i++){int64_t delta=(int64_t)k->targets[i]-(int64_t)(pc+k->ends[i]);int32_t d;if(delta<INT32_MIN||delta>INT32_MAX)return 0;d=delta;memcpy(output+k->offsets[i],&d,4);}return 1;
}
