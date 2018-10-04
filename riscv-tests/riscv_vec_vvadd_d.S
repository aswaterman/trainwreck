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
        vvcfgivl t0,t0,32,0

        la t0,src1
        la t1,src2
        vld vx2,t0
        vld vx3,t1
        lui a0,%hi(vtcode1)
        vf %lo(vtcode1)(a0)
        la t2,dest
        vsd vx2,t2
        fence.l.cv
        ld a1,0(t2)
        li a2,5
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

        la t0,src1
        vld vx4,t0
        lui a0,%hi(vtcode2)
        vf %lo(vtcode2)(a0)
        la t2,dest
        vsd vx4,t2
        fence.l.cv
        ld a1,0(t2)
        li a2,1
        li s8,6
        bne a1,a2,fail
        ld a1,8(t2)
        li a2,2
        li s8,7
        bne a1,a2,fail
        ld a1,16(t2)
        li a2,3
        li s8,8
        bne a1,a2,fail
        ld a1,24(t2)
        li a2,4
        li s8,9
        bne a1,a2,fail

        la t0,src2
        vld vx5,t0
        lui a0,%hi(vtcode3)
        vf %lo(vtcode3)(a0)
        la t2,dest
        vsd vx5,t2
        fence.l.cv
        ld a1,0(t2)
        li a2,4
        li s8,6
        bne a1,a2,fail
        ld a1,8(t2)
        li a2,3
        li s8,7
        bne a1,a2,fail
        ld a1,16(t2)
        li a2,2
        li s8,8
        bne a1,a2,fail
        ld a1,24(t2)
        li a2,1
        li s8,9
        bne a1,a2,fail

        j pass

vtcode1:
        add v0,v0,v1
        stop

vtcode2:
        add a0,a0,x0
        stop

vtcode3:
        add a1,a1,x0
        stop

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END

        .data
src1:
        .dword 1
        .dword 2
        .dword 3
        .dword 4
src2:
        .dword 4
        .dword 3
        .dword 2
        .dword 1
dest:
        .dword 0xdeadbeefcafebabe
        .dword 0xdeadbeefcafebabe
        .dword 0xdeadbeefcafebabe
        .dword 0xdeadbeefcafebabe
