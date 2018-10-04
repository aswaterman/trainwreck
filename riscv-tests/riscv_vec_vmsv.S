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

        li t1,-1
        vmsv vx2,t1
        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)
        la t2,dest
        vsd vx2,t2
        fence.l.cv

        li a1,0
loop:
        ld a0,0(t2)
        addi s8,a1,2
        bne a0,a1,fail
        addi t2,t2,8
        addi a1,a1,1
        bne a1,t0,loop
        j pass

vtcode:
        utidx x1
        addi x1,x1,1
        add x2,x1,x2
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
dest:
        .dword 0xdeadbeefcafebabe
