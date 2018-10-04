#*****************************************************************************
# riscv_lui.S
#-----------------------------------------------------------------------------
#
# Test lui instruction.
#

#include "test_macros.h"

#ifdef __VEC_MACROS
#define DEST0 x0
#define DEST1 x1
#else
#define DEST0 x0
#define DEST1 x1
#endif

        TEST_RISCV_BEGIN
        TEST_STATS_BEGIN

        #-------------------------------------------------------------
        # Basic tests
        #-------------------------------------------------------------

        TEST_CASE( 2, DEST1, 0x0000000000000000, lui x1, 0x00000 );
        TEST_CASE( 3, DEST1, 0xfffffffffffff800, lui x1, 0xfffff;sra x1,x1,1);
        TEST_CASE( 4, DEST1, 0x00000000000007ff, lui x1, 0x7ffff;sra x1,x1,20);
        TEST_CASE( 5, DEST1, 0xfffffffffffff800, lui x1, 0x80000;sra x1,x1,20);

        TEST_CASE( 6, DEST0, 0, lui x0, 0x80000 );

        TEST_STATS_END
        TEST_PASSFAIL
        TEST_RISCV_END
