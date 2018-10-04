#*****************************************************************************
# riscv_fcmp.S
#-----------------------------------------------------------------------------
#
# Test f{eq|lt|le}.{s|d} instructions.
#

#include "test_macros.h"

TEST_RISCV_BEGIN
TEST_STATS_BEGIN

#-------------------------------------------------------------
# Arithmetic tests
#-------------------------------------------------------------

TEST_FP_ENABLE

TEST_FP_CMP_OP_S( 2, feq.s, 1, -1.36, -1.36)
TEST_FP_CMP_OP_S( 3, fle.s, 1, -1.36, -1.36)
TEST_FP_CMP_OP_S( 4, flt.s, 0, -1.36, -1.36)

TEST_FP_CMP_OP_S( 5, feq.s, 0, -1.37, -1.36)
TEST_FP_CMP_OP_S( 6, fle.s, 1, -1.37, -1.36)
TEST_FP_CMP_OP_S( 7, flt.s, 1, -1.37, -1.36)

TEST_STATS_END
TEST_PASSFAIL
TEST_RISCV_END
