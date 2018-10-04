#*****************************************************************************
# riscv-v2_macros.S
#-----------------------------------------------------------------------------
#
# Helper macros for forming test cases.
#

#-----------------------------------------------------------------------
# Begin Macro
#-----------------------------------------------------------------------

#define TEST_RISCV_BEGIN                                                \
        .text;                                                          \
        .align  4;                                                      \
        .global _start;                                                 \
        .ent    _start;                                                 \
_start:                                                                 \
        mfpcr a0,cr0; \
        ori a0,a0,0x6; \
        mtpcr a0,cr0; \
        li t0,0xff; \
        mtpcr t0,cr11; \

#define TEST_STATS_BEGIN                                                \

#-----------------------------------------------------------------------
# End Macro
#-----------------------------------------------------------------------

#define TEST_RISCV_END                                                  \
        .end _start;                                                    \
        .data;                                                          \
dst:                                                                    \
        .dword 0xdeadbeefcafebabe;                                      \

#define TEST_STATS_END                                                  \

#-----------------------------------------------------------------------
# Helper macros
#-----------------------------------------------------------------------

#define TEST_CASE( testnum, testreg, correctval, code... ) \
  TEST_CASE_NREG( testnum, 32, 32, testreg, correctval, code )

# We use j fail, because for some cases branches are not enough to jump to fail

#define TEST_CASE_NREG( testnum, nxreg, nfreg, testreg, correctval, code... ) \
test_ ## testnum: \
  li t0,2048; \
  vvcfgivl t0,t0,nxreg,nfreg; \
  lui a0,%hi(vtcode ## testnum ); \
  vf %lo(vtcode ## testnum )(a0); \
  la t3,dst; \
  vsd v ## testreg, t3; \
  fence.l.cv; \
  li a1,correctval; \
  li a2,0; \
  li x28, testnum; \
loop ## testnum: \
  ld a0,0(t3); \
  beq a0,a1,skip ## testnum; \
  j fail; \
skip ## testnum : \
  addi t3,t3,8; \
  addi a2,a2,1; \
  bne a2,t0,loop ## testnum; \
  j next ## testnum; \
vtcode ## testnum : \
  code; \
  stop; \
next ## testnum :

# We use a macro hack to simpify code generation for various numbers
# of bubble cycles.

#define TEST_INSERT_NOPS_0
#define TEST_INSERT_NOPS_1  nop; TEST_INSERT_NOPS_0
#define TEST_INSERT_NOPS_2  nop; TEST_INSERT_NOPS_1
#define TEST_INSERT_NOPS_3  nop; TEST_INSERT_NOPS_2
#define TEST_INSERT_NOPS_4  nop; TEST_INSERT_NOPS_3
#define TEST_INSERT_NOPS_5  nop; TEST_INSERT_NOPS_4
#define TEST_INSERT_NOPS_6  nop; TEST_INSERT_NOPS_5
#define TEST_INSERT_NOPS_7  nop; TEST_INSERT_NOPS_6
#define TEST_INSERT_NOPS_8  nop; TEST_INSERT_NOPS_7
#define TEST_INSERT_NOPS_9  nop; TEST_INSERT_NOPS_8
#define TEST_INSERT_NOPS_10 nop; TEST_INSERT_NOPS_9

#-----------------------------------------------------------------------
# Tests for instructions with immediate operand
#-----------------------------------------------------------------------

#define TEST_IMM_OP( testnum, inst, result, val1, imm ) \
    TEST_CASE_NREG( testnum, 4, 0, x3, result, \
      li  x1, val1; \
      inst x3, x1, imm; \
    )

#define TEST_IMM_SRC1_EQ_DEST( testnum, inst, result, val1, imm ) \
    TEST_CASE_NREG( testnum, 2, 0, x1, result, \
      li  x1, val1; \
      inst x1, x1, imm; \
    )

#define TEST_IMM_DEST_BYPASS( testnum, nop_cycles, inst, result, val1, imm ) \
    TEST_CASE_NREG( testnum, 5, 0, x4, result, \
      li  x1, val1; \
      inst x3, x1, imm; \
      TEST_INSERT_NOPS_ ## nop_cycles \
      addi  x4, x3, 0; \
    )

#define TEST_IMM_SRC1_BYPASS( testnum, nop_cycles, inst, result, val1, imm ) \
    TEST_CASE_NREG( testnum, 4, 0, x3, result, \
      li  x1, val1; \
      TEST_INSERT_NOPS_ ## nop_cycles \
      inst x3, x1, imm; \
    )

#define TEST_IMM_ZEROSRC1( testnum, inst, result, imm ) \
    TEST_CASE_NREG( testnum, 2, 0, x1, result, \
      inst x1, x0, imm; \
    )

#define TEST_IMM_ZERODEST( testnum, inst, val1, imm ) \
    TEST_CASE_NREG( testnum, 2, 0, x0, 0, \
      li  x1, val1; \
      inst x0, x1, imm; \
    )

#-----------------------------------------------------------------------
# Tests for an instruction with register operands
#-----------------------------------------------------------------------

#define TEST_R_OP( testnum, inst, result, val1 ) \
    TEST_CASE_NREG( testnum, 4, 0, x3, result, \
      li  x1, val1; \
      inst x3, x1; \
    )

#define TEST_R_SRC1_EQ_DEST( testnum, inst, result, val1 ) \
    TEST_CASE_NREG( testnum, 2, 0, x1, result, \
      li  x1, val1; \
      inst x1, x1; \
    )

#define TEST_R_DEST_BYPASS( testnum, nop_cycles, inst, result, val1 ) \
    TEST_CASE_NREG( testnum, 5, 0, x4, result, \
      li  x1, val1; \
      inst x3, x1; \
      TEST_INSERT_NOPS_ ## nop_cycles \
      addi  x4, x3, 0; \
    )

#-----------------------------------------------------------------------
# Tests for an instruction with register-register operands
#-----------------------------------------------------------------------

#define TEST_RR_OP( testnum, inst, result, val1, val2 ) \
    TEST_CASE_NREG( testnum, 4, 0, x3, result, \
      li  x1, val1; \
      li  x2, val2; \
      inst x3, x1, x2; \
    )

#define TEST_RR_SRC1_EQ_DEST( testnum, inst, result, val1, val2 ) \
    TEST_CASE_NREG( testnum, 3, 0, x1, result, \
      li  x1, val1; \
      li  x2, val2; \
      inst x1, x1, x2; \
    )

#define TEST_RR_SRC2_EQ_DEST( testnum, inst, result, val1, val2 ) \
    TEST_CASE_NREG( testnum, 3, 0, x2, result, \
      li  x1, val1; \
      li  x2, val2; \
      inst x2, x1, x2; \
    )

#define TEST_RR_SRC12_EQ_DEST( testnum, inst, result, val1 ) \
    TEST_CASE_NREG( testnum, 2, 0, x1, result, \
      li  x1, val1; \
      inst x1, x1, x1; \
    )

#define TEST_RR_DEST_BYPASS( testnum, nop_cycles, inst, result, val1, val2 ) \
    TEST_CASE_NREG( testnum, 5, 0, x4, result, \
      li  x1, val1; \
      li  x2, val2; \
      inst x3, x1, x2; \
      TEST_INSERT_NOPS_ ## nop_cycles \
      addi  x4, x3, 0; \
    )

#define TEST_RR_SRC12_BYPASS( testnum, src1_nops, src2_nops, inst, result, val1, val2 ) \
    TEST_CASE_NREG( testnum, 4, 0, x3, result, \
      li  x1, val1; \
      TEST_INSERT_NOPS_ ## src1_nops \
      li  x2, val2; \
      TEST_INSERT_NOPS_ ## src2_nops \
      inst x3, x1, x2; \
    )

#define TEST_RR_SRC21_BYPASS( testnum, src1_nops, src2_nops, inst, result, val1, val2 ) \
    TEST_CASE_NREG( testnum, 4, 0, x3, result, \
      li  x2, val2; \
      TEST_INSERT_NOPS_ ## src1_nops \
      li  x1, val1; \
      TEST_INSERT_NOPS_ ## src2_nops \
      inst x3, x1, x2; \
    )

#define TEST_RR_ZEROSRC1( testnum, inst, result, val ) \
    TEST_CASE_NREG( testnum, 3, 0, x2, result, \
      li x1, val; \
      inst x2, x0, x1; \
    )

#define TEST_RR_ZEROSRC2( testnum, inst, result, val ) \
    TEST_CASE_NREG( testnum, 3, 0, x2, result, \
      li x1, val; \
      inst x2, x1, x0; \
    )

#define TEST_RR_ZEROSRC12( testnum, inst, result ) \
    TEST_CASE_NREG( testnum, 2, 0, x1, result, \
      inst x1, x0, x0; \
    )

#define TEST_RR_ZERODEST( testnum, inst, val1, val2 ) \
    TEST_CASE_NREG( testnum, 3, 0, x0, 0, \
      li x1, val1; \
      li x2, val2; \
      inst x0, x1, x2; \
    )

#-----------------------------------------------------------------------
# Tests floating-point instructions
#-----------------------------------------------------------------------

#define TEST_FP_ENABLE \
  mfpcr t0, cr0; \
  or    t0, t0, 2; \
  mtpcr t0, cr0

#define TEST_FP_OP_S_INTERNAL_NREG( testnum, nxreg, nfreg, result, val1, val2, val3, code... ) \
test_ ## testnum: \
  li t0,2048; \
  vvcfgivl t0,t0,nxreg,nfreg; \
  la  t1, test_ ## testnum ## _data ;\
  vflstw vf0, t1, x0; \
  addi t1,t1,4; \
  vflstw vf1, t1, x0; \
  addi t1,t1,4; \
  vflstw vf2, t1, x0; \
  addi t1,t1,4; \
  lui a0,%hi(vtcode ## testnum ); \
  vf %lo(vtcode ## testnum )(a0); \
  la t3,dst; \
  vsw vx1, t3; \
  fence.l.cv; \
  lw  a1, 0(t1); \
  li a2, 0; \
  li x28, testnum; \
loop ## testnum: \
  lw a0,0(t3); \
  beq a0,a1,skip ## testnum; \
  j fail; \
skip ## testnum : \
  addi t3,t3,4; \
  addi a2,a2,1; \
  bne a2,t0,loop ## testnum; \
  b 1f; \
vtcode ## testnum : \
  code; \
  stop; \
  .align 2; \
  test_ ## testnum ## _data: \
  .float val1; \
  .float val2; \
  .float val3; \
  .result; \
1:

#define TEST_FP_OP_D_INTERNAL_NREG( testnum, nxreg, nfreg, result, val1, val2, val3, code... ) \
test_ ## testnum: \
  li t0,2048; \
  vvcfgivl t0,t0,nxreg,nfreg; \
  la  t1, test_ ## testnum ## _data ;\
  vflstd vf0, t1, x0; \
  addi t1,t1,8; \
  vflstd vf1, t1, x0; \
  addi t1,t1,8; \
  vflstd vf2, t1, x0; \
  addi t1,t1,8; \
  lui a0,%hi(vtcode ## testnum ); \
  vf %lo(vtcode ## testnum )(a0); \
  la t3,dst; \
  vsd vx1, t3; \
  fence.l.cv; \
  ld  a1, 0(t1); \
  li a2, 0; \
  li x28, testnum; \
loop ## testnum: \
  ld a0,0(t3); \
  beq a0,a1,skip ## testnum; \
  j fail; \
skip ## testnum : \
  addi t3,t3,8; \
  addi a2,a2,1; \
  bne a2,t0,loop ## testnum; \
  b 1f; \
vtcode ## testnum : \
  code; \
  stop; \
  .align 3; \
  test_ ## testnum ## _data: \
  .double val1; \
  .double val2; \
  .double val3; \
  .result; \
1:

#define TEST_FCVT_S_D( testnum, result, val1 ) \
  TEST_FP_OP_D_INTERNAL_NREG( testnum, 2, 4, double result, val1, 0.0, 0.0, \
                    fcvt.s.d f3, f0; fcvt.d.s f3, f3; mftx.d x1, f3)

#define TEST_FCVT_D_S( testnum, result, val1 ) \
  TEST_FP_OP_S_INTERNAL_NREG( testnum, 2, 4, float result, val1, 0.0, 0.0, \
                    fcvt.d.s f3, f0; fcvt.s.d f3, f3; mftx.s x1, f3)

#define TEST_FP_OP2_S( testnum, inst, result, val1, val2 ) \
  TEST_FP_OP_S_INTERNAL_NREG( testnum, 2, 4, float result, val1, val2, 0.0, \
                    inst f3, f0, f1; mftx.s x1, f3)

#define TEST_FP_OP2_D( testnum, inst, result, val1, val2 ) \
  TEST_FP_OP_D_INTERNAL_NREG( testnum, 2, 4, double result, val1, val2, 0.0, \
                    inst f3, f0, f1; mftx.d x1, f3)

#define TEST_FP_OP3_S( testnum, inst, result, val1, val2, val3 ) \
  TEST_FP_OP_S_INTERNAL_NREG( testnum, 2, 4, float result, val1, val2, val3, \
                    inst f3, f0, f1, f2; mftx.s x1, f3)

#define TEST_FP_OP3_D( testnum, inst, result, val1, val2, val3 ) \
  TEST_FP_OP_D_INTERNAL_NREG( testnum, 2, 4, double result, val1, val2, val3, \
                    inst f3, f0, f1, f2; mftx.d x1, f3)

#define TEST_FP_INT_OP_S( testnum, inst, result, val1, rm ) \
  TEST_FP_OP_S_INTERNAL_NREG( testnum, 2, 4, word result, val1, 0.0, 0.0, \
                    inst x1, f0, rm)

#define TEST_FP_INT_OP_D( testnum, inst, result, val1, rm ) \
  TEST_FP_OP_D_INTERNAL_NREG( testnum, 2, 4, dword result, val1, 0.0, 0.0, \
                    inst x1, f0, rm)

#define TEST_FP_CMP_OP_S( testnum, inst, result, val1, val2 ) \
  TEST_FP_OP_S_INTERNAL_NREG( testnum, 2, 4, word result, val1, val2, 0.0, \
                    inst x1, f0, f1)

#define TEST_FP_CMP_OP_D( testnum, inst, result, val1, val2 ) \
  TEST_FP_OP_D_INTERNAL_NREG( testnum, 2, 4, dword result, val1, val2, 0.0, \
                    inst x1, f0, f1)

#define TEST_INT_FP_OP_S( testnum, inst, result, val1 ) \
test_ ## testnum: \
  li t0,2048; \
  vvcfgivl t0,t0,2,1; \
  lui a0,%hi(vtcode ## testnum ); \
  vf %lo(vtcode ## testnum )(a0); \
  la t3,dst; \
  vsw vx1, t3; \
  fence.l.cv; \
  la  t1, test_ ## testnum ## _data ;\
  lw  a1, 0(t1); \
  li a2, 0; \
  li x28, testnum; \
loop ## testnum: \
  lw a0,0(t3); \
  beq a0,a1,skip ## testnum; \
  j fail; \
skip ## testnum : \
  addi t3,t3,4; \
  addi a2,a2,1; \
  bne a2,t0,loop ## testnum; \
  b 1f; \
vtcode ## testnum : \
  li x1, val1; \
  inst f0, x1; \
  mftx.s x1, f0; \
  stop; \
  .align 2; \
  test_ ## testnum ## _data: \
  .float result; \
1:

#define TEST_INT_FP_OP_D( testnum, inst, result, val1 ) \
test_ ## testnum: \
  li t0,2048; \
  vvcfgivl t0,t0,2,1; \
  lui a0,%hi(vtcode ## testnum ); \
  vf %lo(vtcode ## testnum )(a0); \
  la t3,dst; \
  vsd vx1, t3; \
  fence.l.cv; \
  la  t1, test_ ## testnum ## _data ;\
  ld  a1, 0(t1); \
  li a2, 0; \
  li x28, testnum; \
loop ## testnum: \
  ld a0,0(t3); \
  beq a0,a1,skip ## testnum; \
  j fail; \
skip ## testnum : \
  addi t3,t3,8; \
  addi a2,a2,1; \
  bne a2,t0,loop ## testnum; \
  b 1f; \
vtcode ## testnum : \
  li x1, val1; \
  inst f0, x1; \
  mftx.d x1, f0; \
  stop; \
  .align 3; \
  test_ ## testnum ## _data: \
  .double result; \
1:

#-----------------------------------------------------------------------
# Pass and fail code (assumes test num is in x28)
#-----------------------------------------------------------------------

#define TEST_PASSFAIL \
        bne x0, x28, pass; \
fail: \
        mtpcr x28, cr16; \
1:      beq x0, x0, 1b; \
        nop; \
pass: \
        li  x1, 1; \
        mtpcr x1, cr16; \
1:      beq x0, x0, 1b; \
        nop; \

#-----------------------------------------------------------------------
# Set stats enable/disable
#-----------------------------------------------------------------------

#ifdef  ENABLE_STATS
#define SET_STATS( reg ) \
        mtpcr reg, cr10;       \
        nop; \
        nop; \
        nop; \
        nop; \

#else
#define SET_STATS( enable )
#endif

