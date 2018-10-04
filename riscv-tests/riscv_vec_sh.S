#*****************************************************************************
# riscv_addiw.S
#-----------------------------------------------------------------------------
#
# Test addiw instruction.
#

#include "test_macros_vec.h"

        TEST_RISCV_BEGIN
        TEST_STATS_BEGIN

        li t0,512
        vvcfgivl t0,t0,16,0

        la t2,dest
        li a2,0

initloop:
        sd x0,0(t2)
        addi t2,t2,8
        addi a2,a2,1
        bne a2,t0,initloop
        fence

        la t1,src
        vld vx1,t1
        la t2,dest
        vmsv vx2,t2
        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)
        fence.l.cv

        li a2,0
loop:
        ld a0,0(t2)
        ld a1,0(t1)
        sll a3,a1,48
        srl a3,a3,48
        addi s8,a2,2
        bne a0,a3,fail
        addi t2,t2,8
        addi t1,t1,8
        addi a2,a2,1
        bne a2,t0,loop
        j pass

vtcode:
        utidx v1
        slli v1,v1,3
        add v0,v0,v1
        sh ra,0(v0)
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
src:
#include "riscv_vec_d_data.S"
dest:
        .dword 0
