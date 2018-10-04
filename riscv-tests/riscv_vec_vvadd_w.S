#*****************************************************************************
# riscv_addiw.S
#-----------------------------------------------------------------------------
#
# Test addiw instruction.
#

#include "test_macros_vec.h"

        TEST_RISCV_BEGIN
        TEST_STATS_BEGIN

        li t0,9
        vvcfgivl t0,t0,32,0

        la t0,src1
        la t1,src2
        vlw vx2,t0
        vlw vx3,t1
        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)
        la t2,dest
        vsw vx2,t2
        fence.l.cv
        lw a1,0(t2)
        li a2,10
        li s8,2
        bne a1,a2,fail
        lw a1,4(t2)
        li s8,3
        bne a1,a2,fail
        lw a1,8(t2)
        li s8,4
        bne a1,a2,fail
        lw a1,12(t2)
        li s8,5
        bne a1,a2,fail
        j pass

vtcode:
        addw v0,v0,v1
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
src1:
        .word 1
        .word 2
        .word 3
        .word 4
        .word 5
        .word 6
        .word 7
        .word 8
        .word 9
src2:
        .word 9
        .word 8
        .word 7
        .word 6
        .word 5
        .word 4
        .word 3
        .word 2
        .word 1
dest:
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
