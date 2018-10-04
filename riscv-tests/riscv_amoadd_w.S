#*****************************************************************************
# riscv_amoadd_w.S
#-----------------------------------------------------------------------------
#
# Test amoadd.w instruction.
#

#include "test_macros.h"

    TEST_RISCV_BEGIN
    TEST_STATS_BEGIN

    TEST_CASE(2, a4, 0xffffffff80000000, \
      li a0, 0xffffffff80000000; \
      li a1, 0xfffffffffffff800; \
      la a3, 0x1000; \
      sw a0, 0(a3); \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      amoadd.w	a4, a1, 0(a3); \
    )

    TEST_CASE(3, a5, 0x000000007ffff800, lw a5, 0(a3))

    # try again after a cache miss
    TEST_CASE(4, a4, 0x000000007ffff800, \
      li  a1, 0xffffffff80000000; \
      li  a4, 16384; \
      add a5, a3, a4; \
      lw  x0, 0(a5); \
      add a5, a3, a4; \
      lw  x0, 0(a5); \
      add a5, a3, a4; \
      lw  x0, 0(a5); \
      add a5, a3, a4; \
      lw  x0, 0(a5); \
      amoadd.w a4, a1, 0(a3); \
    )

    TEST_CASE(5, a5, 0xfffffffffffff800, lw a5, 0(a3))

    TEST_STATS_END
    TEST_PASSFAIL
    TEST_RISCV_END
