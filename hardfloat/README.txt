Definition of Recoded Float used by John Hauser

  The recoded format has one extra exponent bit, which is used to normalize
subnormals and also to allow a more efficient coding of the special cases
like zero and NaN.  The attached file shows the correspondence between
standard format (left column) and recoded format (right column) for 32-bit
floating-point (single precision).  In the file, floating-point formats are
shown separated into sign, exponent, and significand fields; and characters
`s', `f', and `-' stand for sign bit, fraction bit, and `don't care',
respectively.  The first case (first line) is zero, and the last two cases
are infinity and NaN.

  s 00000000 00000000000000000000000    s 000------ 00000000000000000000000
  s 00000000 00000000000000000000001    s 001101011 00000000000000000000000
  s 00000000 0000000000000000000001f    s 001101100 f0000000000000000000000
  s 00000000 000000000000000000001ff    s 001101101 ff000000000000000000000
      ...              ...                   ...              ...
  s 00000000 001ffffffffffffffffffff    s 001111111 ffffffffffffffffffff000
  s 00000000 01fffffffffffffffffffff    s 010000000 fffffffffffffffffffff00
  s 00000000 1ffffffffffffffffffffff    s 010000001 ffffffffffffffffffffff0
  s 00000001 fffffffffffffffffffffff    s 010000010 fffffffffffffffffffffff
  s 00000010 fffffffffffffffffffffff    s 010000011 fffffffffffffffffffffff
      ...              ...                   ...              ...
  s 11111101 fffffffffffffffffffffff    s 101111110 fffffffffffffffffffffff
  s 11111110 fffffffffffffffffffffff    s 101111111 fffffffffffffffffffffff
  s 11111111 00000000000000000000000    s 110------ ----------------------- Inf
  s 11111111 fffffffffffffffffffffff    s 111------ fffffffffffffffffffffff NaN


Float to Int and Int to Float conversion notes
Author: John Hauser, 10/13/2010

For conversion from floating-point to integer, either the conversion is invalid (and you raise the invalid flag) or you basically do three steps:
shift the significand right according to the exponent, negate if negative, and possibly round.  Some details:

  - The conversion is invalid if the floating-point source is funky or too
    big for the integer.  Do not raise the overflow or underflow flags.

  - If you're clever, you may be able to arrange the shift so you don't have
    to do arithmetic on the floating-point exponent to determine the shift
    distance, just use the exponent directly.

  - If you're just trying to implement the float-to-int conversion required
    by the C language, you don't need to round, just throw away the bits you
    shift off.

  - If you need to round, you'll want to keep an extra half-place bit and a
    ``sticky'' bit below the rounding point when you shift.  The half-place
    bit is just an extra bit, and the sticky bit is the logical OR of all
    the bits shifted off past the half-place bit.  You round based on the
    values of these two bits, the sign, and the rounding mode.

  - Rounding requires an incrementer, and so does negation.  (Negation
    is complement and increment, of course.)  You can get by with only
    one incrementer for both as follows:  Let S be the significand after
    shifting (with the extra 2 bits).  Let X be the integer part of S (no
    extra bits) conditionally complemented according to the floating-point
    sign; i.e., X = sign ? ~ int(S) : int(S).  The final integer result is
    either X or X + 1, depending on the combination of the rounding mode,
    the extra 2 bits of S, and the sign.

  - Even if the conversion isn't exact, don't raise the inexact exception.

Conversion from integer to floating-point is the reverse procedure:
You record the sign of the integer, and conditionally negate to get the absolute value.  Then you do a normalization shift on the integer to get the floating-point result's significand (the normalized integer value) and its exponent (the distance you had to shift to normalize).  Notes:

  - Conversion in this direction is never invalid.  There is no overflow or
    underflow.  However, if the conversion is not exact, you should raise
    the inexact flag.

  - If the destination floating-point format has a significand larger
    than the source integer format, the conversion is exact; no rounding is
    necessary.  (For example, converting 32-bit integer to 64-bit floating-
    point.)

  - It's possible to use a single incrementer for both negation and
    rounding, similar to the float-to-int conversion above.  Instead of
    fully negating, you complement the input, and then do a single increment
    after the normalization shift.  However, for this to work, when you
    shift, you'll want the bits you shift in on the right to be copies of
    the sign bit (!).

  - The `normalize32' and `normalize64' modules I wrote can be used as
    possible models for doing the normalization.

Conversion from Double to Single:

0      s 9'h000 (0)   00000000000000000000000  s 12'h000

2^-149 s 9'h06b (107) 00000000000000000000000  s 12'h76b 52'h0000000000000
2^-148 s 9'h06c (108) f0000000000000000000000  s 12'h76c 52'h8000000000000
2^-147 s 9'h06d (109) ff000000000000000000000  s 12'h76d 52'hc000000000000
      ...              ...                   ...              ...
2^-129 s 9'h07f (127) ffffffffffffffffffff000  s 12'h77f 52'hfffff00000000
2^-128 s 9'h080 (128) fffffffffffffffffffff00  s 12'h780 52'hfffff80000000
2^-127 s 9'h081 (129) ffffffffffffffffffffff0  s 12'h781 52'hfffffc0000000
2^-126 s 9'h082 (130) fffffffffffffffffffffff  s 12'h782 52'hfffffe0000000
2^-125 s 9'h083 (131) fffffffffffffffffffffff  s 12'h783 52'hfffffe0000000

2^-1   s 9'h0ff (255) fffffffffffffffffffffff  s 12'h7ff 52'hfffffe0000000
2^0    s 9'h100 (256) fffffffffffffffffffffff  s 12'h800 52'hfffffe0000000
2^1    s 9'h101 (257) fffffffffffffffffffffff  s 12'h801 52'hfffffe0000000
      ...              ...                   ...              ...
2^126  s 9'h17e (382) fffffffffffffffffffffff  s 12'h87e 52'hfffffe0000000
2^127  s 9'h17f (383) fffffffffffffffffffffff  s 12'h87f 52'hfffffe0000000

Inf    s 9'h180       -----------------------
NaN    s 9'h1c0       fffffffffffffffffffffff
