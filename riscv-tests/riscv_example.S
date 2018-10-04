#*****************************************************************************
# riscv_simple.S
#-----------------------------------------------------------------------------
#
# This is the most basic self checking test. If your simulator does not
# pass this then there is little chance that it will pass any of the
# more complicated self checking tests.
#

        .text
        .globl _start
        .ent _start
_start:

        # Set the tohost register to one indicating a passed test

        addi x1, x0, 1
        mtpcr x1, cr16

        # Insert some nops so that test harness has time to stop
        # the simulation after it sees a one in tohost

        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop

1:      beq x0, x0, 1b

        .end _start
