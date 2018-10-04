#*****************************************************************************
# riscv_addiw.S
#-----------------------------------------------------------------------------
#
# Test addiw instruction.
#

#include "test_macros_vec.h"

        TEST_RISCV_BEGIN
        TEST_STATS_BEGIN

        li t0,4
        vvcfgivl t0,t0,32,32

        la t0,src1
        la t1,src2
        vflw vf2,t0
        vflw vf3,t1
        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)
        la t2,dest
        vfsw vf2,t2
        fence.l.cv
        la t3,result
        lw a1,0(t2)
        lw a2,0(t3)
        li s8,2
        bne a1,a2,fail
        lw a1,8(t2)
        li s8,3
        bne a1,a2,fail
        lw a1,16(t2)
        li s8,4
        bne a1,a2,fail
        lw a1,24(t2)
        li s8,5
        bne a1,a2,fail
        j pass

vtcode:
        fadd.s f2,f2,f3
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
src1:
        .single 0.1
        .single 0.2
        .single 0.3
        .single 0.4
src2:
        .single 0.4
        .single 0.3
        .single 0.2
        .single 0.1
dest:
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
result:
        .single 0.5
        .single 0.5
        .single 0.5
        .single 0.5
