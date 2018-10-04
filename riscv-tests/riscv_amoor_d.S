#*****************************************************************************
# riscv_amoor_d.S
#-----------------------------------------------------------------------------
#
# Test amoor.d instruction.
#

#include "test_macros.h"

    TEST_RISCV_BEGIN
    TEST_STATS_BEGIN

    TEST_CASE(2, a4, 0xffffffff80000000, \
      li a0, 0xffffffff80000000; \
      li a1, 0xfffffffffffff800; \
      la a3, 0x1000; \
      sd a0, 0(a3); \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      nop; nop; nop; nop; \
      amoor.d	a4, a1, 0(a3); \
    )

    TEST_CASE(3, a5, 0xfffffffffffff800, ld a5, 0(a3))

    # try again after a cache miss
    TEST_CASE(4, a4, 0xfffffffffffff800, \
      li  a1, 1; \
      li  a4, 16384; \
      add a5, a3, a4; \
      ld  x0, 0(a5); \
      add a5, a3, a4; \
      ld  x0, 0(a5); \
      add a5, a3, a4; \
      ld  x0, 0(a5); \
      add a5, a3, a4; \
      ld  x0, 0(a5); \
      amoor.d a4, a1, 0(a3); \
    )

    TEST_CASE(5, a5, 0xfffffffffffff801, ld a5, 0(a3))

    TEST_STATS_END
    TEST_PASSFAIL
    TEST_RISCV_END
