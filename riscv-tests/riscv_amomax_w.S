#*****************************************************************************
# riscv_amomax_d.S
#-----------------------------------------------------------------------------
#
# Test amomax.w instruction.
#

#include "test_macros.h"

    TEST_RISCV_BEGIN
    TEST_STATS_BEGIN

    TEST_CASE(2, a4, 0xffffffff80000000, \
      li a0, 0xffffffff80000000; \
      li a1, 0xfffffffffffff800; \
      la a3, 0x1000; \
      sw a0, 0(a3); \
      amomax.w	a4, a1, 0(a3); \
    )

    TEST_CASE(3, a5, 0xfffffffffffff800, lw a5, 0(a3))

    TEST_CASE(4, a4, 0, \
      li a1, 1; \
      sw x0, 0(a3); \
      amomax.w	a4, a1, 0(a3); \
    )

    TEST_CASE(5, a5, 1, lw a5, 0(a3))

    TEST_STATS_END
    TEST_PASSFAIL
    TEST_RISCV_END
