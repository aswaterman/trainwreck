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
        vvcfgivl t0,t0,4,0

        la t1,amodest
        vmsv vx2,t1
        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)
        la t2,dest
        vsd vx1,t2
        fence.l.cv

        li a1,0
        li a2,0
loop:
        ld a0,0(t2)
        addi s8,a1,2
        bne a0,a2,fail
        addi t2,t2,8
        addi a1,a1,1
        bne a1,t0,loop
        j pass

vtcode:
        utidx v1
        addi v1,v1,1
        li ra,-1
        mul v1,v1,ra
        amominu.d ra,v1,0(v0)
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
amodest:
        .dword 0
dest:
        .dword 0xdeadbeefcafebabe
