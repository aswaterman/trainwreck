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

        la t0,src
        vld vx2,t0
        lui a0,%hi(vtcode)
        vf %lo(vtcode)(a0)
        la t2,dest
        vfsd vf0,t2
        fence.l.cv
        la t3,result
        ld a1,0(t2)
        ld a2,0(t3)
        li s8,2
        bne a1,a2,fail
        ld a1,8(t2)
        ld a2,8(t3)
        li s8,3
        bne a1,a2,fail
        ld a1,16(t2)
        ld a2,16(t3)
        li s8,4
        bne a1,a2,fail
        ld a1,24(t2)
        ld a2,24(t3)
        li s8,5
        bne a1,a2,fail
        j pass

vtcode:
        fcvt.d.l f0,v0
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
src:
        .dword 1
        .dword 2
        .dword 3
        .dword 4
dest:
        .dword 0xdeadbeefcafebabe
        .dword 0xdeadbeefcafebabe
        .dword 0xdeadbeefcafebabe
        .dword 0xdeadbeefcafebabe
result:
        .double 1.0
        .double 2.0
        .double 3.0
        .double 4.0
