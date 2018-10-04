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
        vfld vf2,t0
        vfld vf3,t1
        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)
        la t2,dest
        vfsd vf2,t2
        fence.l.cv
        la t3,result
        ld a1,0(t2)
        ld a2,0(t3)
        li s8,2
        bne a1,a2,fail
        ld a1,8(t2)
        li s8,3
        bne a1,a2,fail
        ld a1,16(t2)
        li s8,4
        bne a1,a2,fail
        ld a1,24(t2)
        li s8,5
        bne a1,a2,fail
        j pass

vtcode:
        fadd.d f2,f2,f3
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
src1:
        .double 0.1
        .double 0.2
        .double 0.3
        .double 0.4
src2:
        .double 0.4
        .double 0.3
        .double 0.2
        .double 0.1
dest:
        .dword 0xdeadbeefcafebabe
        .dword 0xdeadbeefcafebabe
        .dword 0xdeadbeefcafebabe
        .dword 0xdeadbeefcafebabe
result:
        .double 0.5
        .double 0.5
        .double 0.5
        .double 0.5
