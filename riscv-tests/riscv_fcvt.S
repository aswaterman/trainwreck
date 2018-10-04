#*****************************************************************************
# riscv_fcvt.S
#-----------------------------------------------------------------------------
#
# Test fcvt.{s|d}.{wu|w|lu|l}, fcvt.s.d, and fcvt.d.s instructions.
#

#include "test_macros.h"

TEST_RISCV_BEGIN
TEST_STATS_BEGIN

#-------------------------------------------------------------
# Arithmetic tests
#-------------------------------------------------------------

TEST_FP_ENABLE

TEST_INT_FP_OP_S( 2,  fcvt.s.w,                   2.0,  2);
TEST_INT_FP_OP_S( 3,  fcvt.s.w,                  -2.0, -2);

TEST_INT_FP_OP_S( 4, fcvt.s.wu,                   2.0,  2);
TEST_INT_FP_OP_S( 5, fcvt.s.wu,           4.2949673e9, -2);

TEST_INT_FP_OP_S( 6,  fcvt.s.l,                   2.0,  2);
TEST_INT_FP_OP_S( 7,  fcvt.s.l,                  -2.0, -2);

TEST_INT_FP_OP_S( 8, fcvt.s.lu,                   2.0,  2);
TEST_INT_FP_OP_S( 9, fcvt.s.lu,          1.8446744e19, -2);

TEST_INT_FP_OP_D(12,  fcvt.d.w,                   2.0,  2);
TEST_INT_FP_OP_D(13,  fcvt.d.w,                  -2.0, -2);

TEST_INT_FP_OP_D(14, fcvt.d.wu,                   2.0,  2);
TEST_INT_FP_OP_D(15, fcvt.d.wu,            4294967294, -2);

TEST_INT_FP_OP_D(16,  fcvt.d.l,                   2.0,  2);
TEST_INT_FP_OP_D(17,  fcvt.d.l,                  -2.0, -2);

TEST_INT_FP_OP_D(18, fcvt.d.lu,                   2.0,  2);
TEST_INT_FP_OP_D(19, fcvt.d.lu, 1.8446744073709552e19, -2);

TEST_FCVT_S_D(20, -1.5, -1.5)
TEST_FCVT_D_S(21, -1.5, -1.5)

TEST_STATS_END
TEST_PASSFAIL
TEST_RISCV_END
