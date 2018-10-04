#*****************************************************************************
# riscv_addiw.S
#-----------------------------------------------------------------------------
#
# Test addiw instruction.
#

#include "test_macros.h"

        TEST_RISCV_BEGIN
        TEST_STATS_BEGIN

        mfpcr a0,cr0;
        ori a0,a0,0x6;
        mtpcr a0,cr0;

        # make sure these don't choke at the beginning
        fence.l.cv
        fence.l.v
        fence.g.cv
        fence.g.v

        # this shouldn't go through since app vl is zero
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
        li a2,0xdeadbeefcafebabe
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

        # check default hw vector length, which is 32
        li t0, 32
        vsetvl t0, t0
        li a0, 32
        li s8, 6
        bne t0, a0, fail

        li t0, 33
        vsetvl t0, t0
        li a0, 32
        li s8, 7
        bne t0, a0, fail

        li t0, 31
        vsetvl t0, t0
        li a0, 31
        li s8, 8
        bne t0, a0, fail

        # now do some vector stuff without vvcfgivl
        vsetvl x0, x0

        li t0, 4
        la t1,src1
        la t2,src2
        vsetvl t0, t0
        vld vx2,t1
        vld vx3,t2
        lui a0,%hi(vtcode1)
        vf %lo(vtcode1)(a0)
        la t2,dest
        vsd vx2,t2
        fence.l.cv

        ld a1,0(t2)
        li a2,5
        li s8,9
        bne a1,a2,fail
        ld a1,8(t2)
        li s8,10
        bne a1,a2,fail
        ld a1,16(t2)
        li s8,11
        bne a1,a2,fail
        ld a1,24(t2)
        li s8,12
        bne a1,a2,fail

        # initialize dest memory
        li t0, 0xdeadbeefcafebabe
        sd t0, 0(t2)
        sd t0, 8(t2)
        sd t0, 16(t2)
        sd t0, 24(t2)

        # test app vl zero again
        li t0, 0
        vsetvl t0, t0

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
        li a2,0xdeadbeefcafebabe
        li s8,13
        bne a1,a2,fail
        ld a1,8(t2)
        li s8,14
        bne a1,a2,fail
        ld a1,16(t2)
        li s8,15
        bne a1,a2,fail
        ld a1,24(t2)
        li s8,16
        bne a1,a2,fail

        j pass

vtcode1:
        add v0,v0,v1
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
