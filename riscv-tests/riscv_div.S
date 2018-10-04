#*****************************************************************************
# riscv_div.S
#-----------------------------------------------------------------------------
#
# Test div instruction.
#

#include "test_macros.h"

        TEST_RISCV_BEGIN
        TEST_STATS_BEGIN

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------

        TEST_RR_OP( 2, div,  3,  20,   6 );
        TEST_RR_OP( 3, div, -3, -20,   6 );
        TEST_RR_OP( 4, div, -3,  20,  -6 );
        TEST_RR_OP( 5, div,  3, -20,  -6 );

        TEST_RR_OP( 6, div, -1<<63, -1<<63,  1 );
        TEST_RR_OP( 7, div, -1<<63, -1<<63, -1 );

        TEST_RR_OP( 8, div, -1, -1<<63, 0 );
        TEST_RR_OP( 9, div, -1,      1, 0 );
        TEST_RR_OP(10, div, -1,      0, 0 );

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END
