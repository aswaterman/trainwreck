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

        li t0,1
        bne t0,x0,skip1
        fence.l.cv
skip1:

        bne t0,x0,skip2
        fence.l.v
skip2:

        bne t0,x0,skip3
        fence.g.cv
skip3:

        bne t0,x0,skip4
        fence.g.v
skip4:

        j pass

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
