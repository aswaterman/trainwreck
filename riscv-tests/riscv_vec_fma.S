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
        vvcfgivl t0,t0,3,2

        la t1,src
        fld f0,0(t1)
        fld f1,8(t1)
        mftx.d s0,f0
        mftx.d s1,f1
        vmsv vx1,s0
        vmsv vx2,s1
        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)

        li t7,0
        li t6,400
wait:
        addi t7,t7,1
        bne t7,t6,wait

        fadd.d f0,f0,f1
        mftx.d s2,f0

        la t2,dest
        vfsd vf0,t2
        fence.l.cv

        la s3,result
        ld s4,0(s3)
        li s8,2
        bne s2,s4,fail

        li a2,0
loop:
        ld a0,0(t2)
        addi s8,a2,3
        bne a0,s4,fail
        addi t2,t2,8
        addi a2,a2,1
        bne a2,t0,loop
        j pass

vtcode:
        mxtf.d f0,x1
        mxtf.d f1,x2
        fadd.d f0,f0,f1
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
src:
        .double 1.0
        .double 2.0
result:
        .double 3.0
dest:
        .dword 0xdeadbeefcafebabe
