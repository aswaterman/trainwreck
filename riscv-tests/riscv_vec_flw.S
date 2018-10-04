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
        vvcfgivl t0,t0,4,1

        la t1,src
        vmsv vx2,t1
        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)
        la t2,dest
        vfsw vf0,t2
        fence.l.cv

        li a2,0
loop:
        lw a0,0(t2)
        addi s8,a2,2
        lw a1,0(t1)
        bne a0,a1,fail
        addi t2,t2,4
        addi t1,t1,4
        addi a2,a2,1
        bne a2,t0,loop
        j pass

vtcode:
        utidx v1
        slli v1,v1,2
        add v0,v0,v1
        flw f0,0(v0)
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
src:
#include "riscv_vec_fw_data.S"

dest:
        .align 2
        .word 0xdeadbeef
