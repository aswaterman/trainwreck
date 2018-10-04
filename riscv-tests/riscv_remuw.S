#*****************************************************************************
# riscv_remuw.S
#-----------------------------------------------------------------------------
#
# Test remuw instruction.
#

#include "test_macros.h"

        TEST_RISCV_BEGIN
        TEST_STATS_BEGIN

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------

        TEST_RR_OP( 2, remuw,   2,  20,   6 );
        TEST_RR_OP( 3, remuw,   2, -20,   6 );
        TEST_RR_OP( 4, remuw,  20,  20,  -6 );
        TEST_RR_OP( 5, remuw, -20, -20,  -6 );

        TEST_RR_OP( 6, remuw,      0, -1<<31,  1 );
        TEST_RR_OP( 7, remuw, -1<<31, -1<<31, -1 );

        TEST_RR_OP( 8, remuw, -1<<31, -1<<31, 0 );
        TEST_RR_OP( 9, remuw,      1,      1, 0 );
        TEST_RR_OP(10, remuw,      0,      0, 0 );

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END
