#*****************************************************************************
# riscv_addiw.S
#-----------------------------------------------------------------------------
#
# Test addiw instruction.
#

#include "test_macros_vec.h"

        TEST_RISCV_BEGIN
        TEST_STATS_BEGIN

        li t0,2048
        vvcfgivl t0,t0,3,0

        li t1,20
        li s0,2
        vmsv vx1,t1
        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)

        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        mul s1,t1,s0

        la t2,dest
        vsd vx1,t2
        fence.l.cv

        li s2,40
        li s8,2
        bne s1,s2,fail

        li a1,0
        li a2,0
loop:
        ld a0,0(t2)
        addi s8,a2,3
        bne a0,a1,fail
        addi t2,t2,8
        addi a1,a1,20
        addi a2,a2,1
        bne a2,t0,loop
        j pass

vtcode:
        utidx x2
        mul x1,x2,x1
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
dest:
        .dword 0xdeadbeefcafebabe
