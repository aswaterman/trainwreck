#*****************************************************************************
# riscv_fp_move.S
#-----------------------------------------------------------------------------
#
# This test verifies that mftx.s, mftx.d, mftxl.d, mftxh.d, mxtf.s, mxtf.d,
# and mxtflh.d work properly.
#

        .text
        .globl _start
        .ent _start
_start:

    mfpcr x20,cr0
    or x20,x20,0x2
    mtpcr x20,cr0

		li		x25, 1

        # compute -(((1 + 2)*2)*2+1) and verify intermediate results

		li		x1, 0xFFFFFFFFBF812345
		mxtf.s	f1, x1
		mftx.s	x2, f1

		beq		x2, x1, 1f
		li		x25, 2
		b		done
1:		

		li		x1, 0x000000003FF02468A0000000
		mxtf.d	f1, x1
		mftx.d	x2, f1

		beq		x2, x1, 1f
		li		x25, 3
		b		done
1:		

done:	mtpcr	x25, cr16

1:      b		1b

        .end _start
