	.sdata
	.globl	_heapend
	.globl	environ
_heapend:
	.word	0
environ:
	.word	0

	.text
	.globl _start
	.ent	_start

_start:
	li	$x1, 0
	li	$x2, 0
	li	$x3, 0
	li	$x4, 0
	li	$x5, 0
	li	$x6, 0
	li	$x7, 0
	li	$x8, 0
	li	$x9, 0
	li	$x10,0
	li	$x11,0
	li	$x12,0
	li	$x13,0
	li	$x14,0
	li	$x15,0
	li	$x16,0
	li	$x17,0
	li	$x18,0
	li	$x19,0
	li	$x20,0
	li	$x21,0
	li	$x22,0
	li	$x23,0
	li	$x24,0
	li	$x25,0
	li	$x26,0
	li	$x27,0
	li	$x28,0
	li	$x29,0
	li	$x30,0
	li	$x31,0

	mfpcr	$x1,$cr0
	ori	$x1,$x1,0x10
	mtpcr	$x1,$cr0

	#mtf.d	$f0, $x0
	#mtf.d	$f1, $x0
	#mtf.d	$f2, $x0
	#mtf.d	$f3, $x0
	#mtf.d	$f4, $x0
	#mtf.d	$f5, $x0
	#mtf.d	$f6, $x0
	#mtf.d	$f7, $x0
	#mtf.d	$f8, $x0
	#mtf.d	$f9, $x0
	#mtf.d	$f10,$x0
	#mtf.d	$f11,$x0
	#mtf.d	$f12,$x0
	#mtf.d	$f13,$x0
	#mtf.d	$f14,$x0
	#mtf.d	$f15,$x0
	#mtf.d	$f16,$x0
	#mtf.d	$f17,$x0
	#mtf.d	$f18,$x0
	#mtf.d	$f19,$x0
	#mtf.d	$f20,$x0
	#mtf.d	$f21,$x0
	#mtf.d	$f22,$x0
	#mtf.d	$f23,$x0
	#mtf.d	$f24,$x0
	#mtf.d	$f25,$x0
	#mtf.d	$f26,$x0
	#mtf.d	$f27,$x0
	#mtf.d	$f28,$x0
	#mtf.d	$f29,$x0
	#mtf.d	$f30,$x0
	#mtf.d	$f31,$x0

	la	$sp,0x1FFF0
	jal	main
	nop
	nop

	.end	_start
