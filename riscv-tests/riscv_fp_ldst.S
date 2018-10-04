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

    mfpcr x20,cr0
    or x20,x20,0x2
    mtpcr x20,cr0

    la     x1, tdat
    flw    f0, 0(x1)
    flw    f1, 4(x1)
    fadd.s f0, f0, f1
    fsw    f0,12(x1)

    lw     x3,12(x1)
    lw     x1, 8(x1)

    li     x2, 2
    bne    x1, x3, 1f
    li     x2, 1
1:  mtpcr  x2, cr16

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

tdat:   .word 0x3f800000
        .word 0x40000000
        .word 0x40400000
