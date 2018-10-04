#*****************************************************************************
# riscv_coreid.S
#-----------------------------------------------------------------------------
#
# Test lui instruction.
#

#include "test_macros.h"

        TEST_RISCV_BEGIN
        TEST_STATS_BEGIN

        #-------------------------------------------------------------
        # Basic tests
        #-------------------------------------------------------------

        TEST_CASE( 2, x1, 0x1, mfpcr x1, cr12 );

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END
