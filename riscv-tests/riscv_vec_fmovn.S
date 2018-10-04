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
        vvcfgivl t0,t0,4,2

        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)
        la t2,dest
        vfsd vf0,t2
        fence.l.cv

        li a1,0
        li a2,-1
loop:
        ld a0,0(t2)
        slti a4,a1,10
        slli a4,a4,63
        srai a4,a4,63
        and a5,a2,a4
        addi s8,a1,2
        bne a0,a5,fail
        addi t2,t2,8
        addi a1,a1,1
        bne a1,t0,loop
        j pass

vtcode:
        utidx x1
        slti x2,x1,10
        li x1,-1
        li x3,0
        mxtf.d f0,x3
        mxtf.d f1,x1
        fmovn f0,x2,f1
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
dest:
        .dword 0xdeadbeefcafebabe
