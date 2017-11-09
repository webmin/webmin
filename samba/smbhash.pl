#
# Samba LM/NT Hash Generating Library.
# Slightly modified to fit in with Webmin
#
# Copyright(C) 2001 Benjamin Kuit <bj@it.uts.edu.au>
#

# Works out if local system has the module Digest::MD4, and uses it
# if it does, otherwise uses ported version of the md4 algorithm
# Performance is a lot better with Digest::MD4, so its recommended to
# get Digest::MD4 installed if you intend to generate a lot of hashes
# in a small amount of time.
my $HaveDigestMD4;

BEGIN {
	$HaveDigestMD4 = 0;
	if ( eval "require 'Digest/MD4.pm';" ) {
		$HaveDigestMD4 = 1;
	}
}

# lmhash PASSWORD
# Generates lanman password hash for a given password, returns the hash
#
# Extracted and ported from SAMBA/source/libsmb/smbencrypt.c:nt_lm_owf_gen
sub lmhash($) {
	my ( $pass ) = @_;
	my ( @p16 );

	$pass = substr($pass||"",0,129);
	$pass =~ tr/a-z/A-Z/;
	$pass = substr($pass,0,14);
	@p16 = E_P16($pass);
	return join("", map {sprintf("%02X",$_);} @p16);
}

# nthash PASSWORD
# Generates nt md4 password hash for a given password, returns the hash
#
# Extracted and ported from SAMBA/source/libsmb/smbencrypt.c:nt_lm_owf_gen
sub nthash($) {
	my ( $pass ) = @_;
	my ( $hex );
	my ( $digest );
	$pass = substr($pass||"",0,128);
	$pass =~ s/(.)/$1\000/sg;
	$hex = "";
	if ( $HaveDigestMD4 ) {
		eval {
			$digest = new Digest::MD4;
			$digest->reset();
			$digest->add($pass);
			$hex = $digest->hexdigest();
			$hex =~ tr/a-z/A-Z/;
		};
		$HaveDigestMD4 = 0 unless ( $hex );
	}
	$hex = sprintf("%02X"x16,mdfour($pass)) unless ( $hex );
	return $hex;
}

# ntlmgen PASSWORD, LMHASH, NTHASH
# Generate lanman and nt md4 password hash for given password, and assigns
# values to arguments. Combined function of lmhash and nthash
sub ntlmgen {
	my ( $nthash, $lmhash );
	$nthash = nthash($_[0]);
	$lmhash = lmhash($_[0]);
	if ( $#_ == 2 ) {
		$_[1] = $lmhash;
		$_[2] = $nthash;
	}
	return ( $lmhash, $nthash );
}

# Support functions
# Ported from SAMBA/source/lib/md4.c:F,G and H respectfully
sub F { my ( $X, $Y, $Z ) = @_; return ($X&$Y) | ((~$X)&$Z); }
sub G { my ( $X, $Y, $Z) = @_; return ($X&$Y) | ($X&$Z) | ($Y&$Z); }
sub H { my ($X, $Y, $Z) = @_; return $X^$Y^$Z; }

# Needed? because perl seems to choke on overflowing when doing bitwise
# operations on numbers larger than 32 bits. Well, it did on my machine =)
sub add32 {
	my ( @v ) = @_;
	my ( $ret, @sum );
	foreach ( @v ) {
		$_ = [ ($_&0xffff0000)>>16, ($_&0xffff) ];
	}
	@sum = ();
	foreach ( @v ) {
		$sum[0] += $_->[0];
		$sum[1] += $_->[1];
	}
	$sum[0] += ($sum[1]&0xffff0000)>>16;
	$sum[1] &= 0xffff;
	$sum[0] &= 0xffff;
	$ret = ($sum[0]<<16) | $sum[1];
	return $ret;
}
# Ported from SAMBA/source/lib/md4.c:lshift
# Renamed to prevent clash with SAMBA/source/libsmb/smbdes.c:lshift
sub md4lshift {
	my ($x, $s) = @_;
	$x &= 0xFFFFFFFF;
	return (($x<<$s)&0xFFFFFFFF) | ($x>>(32-$s));
}
# Ported from SAMBA/source/lib/md4.c:ROUND1
sub ROUND1 {
	my($a,$b,$c,$d,$k,$s,@X) = @_;
	$_[0] = md4lshift(add32($a,F($b,$c,$d),$X[$k]), $s);
	return $_[0];
}
# Ported from SAMBA/source/lib/md4.c:ROUND2
sub ROUND2 {
	my ($a,$b,$c,$d,$k,$s,@X) = @_;
	$_[0] = md4lshift(add32($a,G($b,$c,$d),$X[$k],0x5A827999), $s);
	return $_[0];
}
# Ported from SAMBA/source/lib/md4.c:ROUND3
sub ROUND3 {
	my ($a,$b,$c,$d,$k,$s,@X) = @_;
	$_[0] = md4lshift(add32($a,H($b,$c,$d),$X[$k],0x6ED9EBA1), $s);
	return $_[0];
}
# Ported from SAMBA/source/lib/md4.c:mdfour64
sub mdfour64 {
	my ( $A, $B, $C, $D, @M ) = @_;
	my ( $AA, $BB, $CC, $DD );
	my ( @X );
	@X = (map { $_?$_:0 } @M)[0..15];
	$AA=$A; $BB=$B; $CC=$C; $DD=$D;
        ROUND1($A,$B,$C,$D,  0,  3, @X);  ROUND1($D,$A,$B,$C,  1,  7, @X);
        ROUND1($C,$D,$A,$B,  2, 11, @X);  ROUND1($B,$C,$D,$A,  3, 19, @X);
        ROUND1($A,$B,$C,$D,  4,  3, @X);  ROUND1($D,$A,$B,$C,  5,  7, @X);
        ROUND1($C,$D,$A,$B,  6, 11, @X);  ROUND1($B,$C,$D,$A,  7, 19, @X);
        ROUND1($A,$B,$C,$D,  8,  3, @X);  ROUND1($D,$A,$B,$C,  9,  7, @X);
        ROUND1($C,$D,$A,$B, 10, 11, @X);  ROUND1($B,$C,$D,$A, 11, 19, @X);
        ROUND1($A,$B,$C,$D, 12,  3, @X);  ROUND1($D,$A,$B,$C, 13,  7, @X);
        ROUND1($C,$D,$A,$B, 14, 11, @X);  ROUND1($B,$C,$D,$A, 15, 19, @X);
        ROUND2($A,$B,$C,$D,  0,  3, @X);  ROUND2($D,$A,$B,$C,  4,  5, @X);
        ROUND2($C,$D,$A,$B,  8,  9, @X);  ROUND2($B,$C,$D,$A, 12, 13, @X);
        ROUND2($A,$B,$C,$D,  1,  3, @X);  ROUND2($D,$A,$B,$C,  5,  5, @X);
        ROUND2($C,$D,$A,$B,  9,  9, @X);  ROUND2($B,$C,$D,$A, 13, 13, @X);
        ROUND2($A,$B,$C,$D,  2,  3, @X);  ROUND2($D,$A,$B,$C,  6,  5, @X);
        ROUND2($C,$D,$A,$B, 10,  9, @X);  ROUND2($B,$C,$D,$A, 14, 13, @X);
        ROUND2($A,$B,$C,$D,  3,  3, @X);  ROUND2($D,$A,$B,$C,  7,  5, @X);
        ROUND2($C,$D,$A,$B, 11,  9, @X);  ROUND2($B,$C,$D,$A, 15, 13, @X);
        ROUND3($A,$B,$C,$D,  0,  3, @X);  ROUND3($D,$A,$B,$C,  8,  9, @X);
        ROUND3($C,$D,$A,$B,  4, 11, @X);  ROUND3($B,$C,$D,$A, 12, 15, @X);
        ROUND3($A,$B,$C,$D,  2,  3, @X);  ROUND3($D,$A,$B,$C, 10,  9, @X);
        ROUND3($C,$D,$A,$B,  6, 11, @X);  ROUND3($B,$C,$D,$A, 14, 15, @X);
        ROUND3($A,$B,$C,$D,  1,  3, @X);  ROUND3($D,$A,$B,$C,  9,  9, @X);
        ROUND3($C,$D,$A,$B,  5, 11, @X);  ROUND3($B,$C,$D,$A, 13, 15, @X);
        ROUND3($A,$B,$C,$D,  3,  3, @X);  ROUND3($D,$A,$B,$C, 11,  9, @X);
        ROUND3($C,$D,$A,$B,  7, 11, @X);  ROUND3($B,$C,$D,$A, 15, 15, @X);
	# We want to change the arguments, so assign them to $_[0] markers
	# rather than to $A..$D
	$_[0] = add32($A,$AA); $_[1] = add32($B,$BB);
	$_[2] = add32($C,$CC); $_[3] = add32($D,$DD);
	@X = map { 0 } (1..16);
}

# Ported from SAMBA/source/lib/md4.c:copy64
sub copy64 {
	my ( @in ) = @_;
	my ( $i, @M );
	for $i ( 0..15 ) {
		$M[$i] = ($in[$i*4+3]<<24) | ($in[$i*4+2]<<16) |
                        ($in[$i*4+1]<<8) | ($in[$i*4+0]<<0);
	}
	return @M;
}
# Ported from SAMBA/source/lib/md4.c:copy4
sub copy4 {
	my ( $x ) = @_;
	my ( @out );
        $out[0] = $x&0xFF;
        $out[1] = ($x>>8)&0xFF;
        $out[2] = ($x>>16)&0xFF;
        $out[3] = ($x>>24)&0xFF;
	@out = map { $_?$_:0 } @out;
	return @out;
}
# Ported from SAMBA/source/lib/md4.c:mdfour
sub mdfour {
	my ( @in ) = unpack("C*",$_[0]);
	my ( $b, @A, @M, @buf, @out );
	$b = scalar @in * 8;
	@A = ( 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476 );
	while (scalar @in > 64 ) {
		@M = copy64( @in );
		mdfour64( @A, @M );
		@in = @in[64..$#in];
	}
	@buf = ( @in, 0x80, map {0} (1..128) )[0..127];
	if ( scalar @in <= 55 ) {
		@buf[56..59] = copy4( $b );
		@M = copy64( @buf );
		mdfour64( @A, @M );
	}
	else {
		@buf[120..123] = copy4( $b );
		@M = copy64( @buf );
		mdfour64( @A, @M );
		@M = copy64( @buf[64..$#buf] );
		mdfour64( @A, @M );
	}
	@out[0..3] = copy4($A[0]);
	@out[4..7] = copy4($A[1]);
	@out[8..11] = copy4($A[2]);
	@out[12..15] = copy4($A[3]);
	return @out;
}
# Contants used in lanlam hash calculations
# Ported from SAMBA/source/libsmb/smbdes.c:perm1[56]
my @perm1 = (57, 49, 41, 33, 25, 17,  9,
              1, 58, 50, 42, 34, 26, 18,
             10,  2, 59, 51, 43, 35, 27,
             19, 11,  3, 60, 52, 44, 36,
             63, 55, 47, 39, 31, 23, 15,
              7, 62, 54, 46, 38, 30, 22,
             14,  6, 61, 53, 45, 37, 29,
             21, 13,  5, 28, 20, 12,  4);
# Ported from SAMBA/source/libsmb/smbdes.c:perm2[48]
my @perm2 = (14, 17, 11, 24,  1,  5,
              3, 28, 15,  6, 21, 10,
             23, 19, 12,  4, 26,  8,
             16,  7, 27, 20, 13,  2,
             41, 52, 31, 37, 47, 55,
             30, 40, 51, 45, 33, 48,
             44, 49, 39, 56, 34, 53,
             46, 42, 50, 36, 29, 32);
# Ported from SAMBA/source/libsmb/smbdes.c:perm3[64]
my @perm3 = (58, 50, 42, 34, 26, 18, 10,  2,
             60, 52, 44, 36, 28, 20, 12,  4,
             62, 54, 46, 38, 30, 22, 14,  6,
             64, 56, 48, 40, 32, 24, 16,  8,
             57, 49, 41, 33, 25, 17,  9,  1,
             59, 51, 43, 35, 27, 19, 11,  3,
             61, 53, 45, 37, 29, 21, 13,  5,
             63, 55, 47, 39, 31, 23, 15,  7);
# Ported from SAMBA/source/libsmb/smbdes.c:perm4[48]
my @perm4 = (   32,  1,  2,  3,  4,  5,
                 4,  5,  6,  7,  8,  9,
                 8,  9, 10, 11, 12, 13,
                12, 13, 14, 15, 16, 17,
                16, 17, 18, 19, 20, 21,
                20, 21, 22, 23, 24, 25,
                24, 25, 26, 27, 28, 29,
                28, 29, 30, 31, 32,  1);
# Ported from SAMBA/source/libsmb/smbdes.c:perm5[32]
my @perm5 = (      16,  7, 20, 21,
                   29, 12, 28, 17,
                    1, 15, 23, 26,
                    5, 18, 31, 10,
                    2,  8, 24, 14,
                   32, 27,  3,  9,
                   19, 13, 30,  6,
                   22, 11,  4, 25);
# Ported from SAMBA/source/libsmb/smbdes.c:perm6[64]
my @perm6 =( 40,  8, 48, 16, 56, 24, 64, 32,
             39,  7, 47, 15, 55, 23, 63, 31,
             38,  6, 46, 14, 54, 22, 62, 30,
             37,  5, 45, 13, 53, 21, 61, 29,
             36,  4, 44, 12, 52, 20, 60, 28,
             35,  3, 43, 11, 51, 19, 59, 27,
             34,  2, 42, 10, 50, 18, 58, 26,
             33,  1, 41,  9, 49, 17, 57, 25);
# Ported from SAMBA/source/libsmb/smbdes.c:sc[16]
my @sc = (1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1);
# Ported from SAMBA/source/libsmb/smbdes.c:sbox[8][4][16]
# Side note, I used cut and paste for all these numbers, I did NOT
# type them all in =)
my @sbox = ([[14,  4, 13,  1,  2, 15, 11,  8,  3, 10,  6, 12,  5,  9,  0,  7],
             [ 0, 15,  7,  4, 14,  2, 13,  1, 10,  6, 12, 11,  9,  5,  3,  8],
             [ 4,  1, 14,  8, 13,  6,  2, 11, 15, 12,  9,  7,  3, 10,  5,  0],
             [15, 12,  8,  2,  4,  9,  1,  7,  5, 11,  3, 14, 10,  0,  6, 13]],
            [[15,  1,  8, 14,  6, 11,  3,  4,  9,  7,  2, 13, 12,  0,  5, 10],
             [ 3, 13,  4,  7, 15,  2,  8, 14, 12,  0,  1, 10,  6,  9, 11,  5],
             [ 0, 14,  7, 11, 10,  4, 13,  1,  5,  8, 12,  6,  9,  3,  2, 15],
             [13,  8, 10,  1,  3, 15,  4,  2, 11,  6,  7, 12,  0,  5, 14,  9]],
            [[10,  0,  9, 14,  6,  3, 15,  5,  1, 13, 12,  7, 11,  4,  2,  8],
             [13,  7,  0,  9,  3,  4,  6, 10,  2,  8,  5, 14, 12, 11, 15,  1],
             [13,  6,  4,  9,  8, 15,  3,  0, 11,  1,  2, 12,  5, 10, 14,  7],
             [ 1, 10, 13,  0,  6,  9,  8,  7,  4, 15, 14,  3, 11,  5,  2, 12]],
            [[ 7, 13, 14,  3,  0,  6,  9, 10,  1,  2,  8,  5, 11, 12,  4, 15],
             [13,  8, 11,  5,  6, 15,  0,  3,  4,  7,  2, 12,  1, 10, 14,  9],
             [10,  6,  9,  0, 12, 11,  7, 13, 15,  1,  3, 14,  5,  2,  8,  4],
             [ 3, 15,  0,  6, 10,  1, 13,  8,  9,  4,  5, 11, 12,  7,  2, 14]],
            [[ 2, 12,  4,  1,  7, 10, 11,  6,  8,  5,  3, 15, 13,  0, 14,  9],
             [14, 11,  2, 12,  4,  7, 13,  1,  5,  0, 15, 10,  3,  9,  8,  6],
             [ 4,  2,  1, 11, 10, 13,  7,  8, 15,  9, 12,  5,  6,  3,  0, 14],
             [11,  8, 12,  7,  1, 14,  2, 13,  6, 15,  0,  9, 10,  4,  5,  3]],
            [[12,  1, 10, 15,  9,  2,  6,  8,  0, 13,  3,  4, 14,  7,  5, 11],
             [10, 15,  4,  2,  7, 12,  9,  5,  6,  1, 13, 14,  0, 11,  3,  8],
             [ 9, 14, 15,  5,  2,  8, 12,  3,  7,  0,  4, 10,  1, 13, 11,  6],
             [ 4,  3,  2, 12,  9,  5, 15, 10, 11, 14,  1,  7,  6,  0,  8, 13]],
            [[ 4, 11,  2, 14, 15,  0,  8, 13,  3, 12,  9,  7,  5, 10,  6,  1],
             [13,  0, 11,  7,  4,  9,  1, 10, 14,  3,  5, 12,  2, 15,  8,  6],
             [ 1,  4, 11, 13, 12,  3,  7, 14, 10, 15,  6,  8,  0,  5,  9,  2],
             [ 6, 11, 13,  8,  1,  4, 10,  7,  9,  5,  0, 15, 14,  2,  3, 12]],
            [[13,  2,  8,  4,  6, 15, 11,  1, 10,  9,  3, 14,  5,  0, 12,  7],
             [ 1, 15, 13,  8, 10,  3,  7,  4, 12,  5,  6, 11,  0, 14,  9,  2],
             [ 7, 11,  4,  1,  9, 12, 14,  2,  0,  6, 10, 13, 15,  3,  5,  8],
             [ 2,  1, 14,  7,  4, 10,  8, 13, 15, 12,  9,  0,  3,  5,  6, 11]]);

# Ported from SAMBA/source/libsmb/smbdes.c:xor
# Hack: Split arguments in half and then xor's first half of arguments to
# second half of arguments. Probably proper way of doing this would
# be to used referenced variables
sub mxor {
	my ( @in ) = @_;
	my ( $i, $off, @ret );
	$off = int($#in/2);
	for $i ( 0..$off ) {
		$ret[$i] = $in[$i] ^ $in[$i+$off+1];
	}
	return @ret;
}

# Ported from SAMBA/source/libsmb/smbdes.c:str_to_key
sub str_to_key {
	my ( @str ) = @_;
	my ( $i, @key );
	@str = map { $_?$_:0 } @str;
	$key[0] = $str[0]>>1;
        $key[1] = (($str[0]&0x01)<<6) | ($str[1]>>2);
        $key[2] = (($str[1]&0x03)<<5) | ($str[2]>>3);
        $key[3] = (($str[2]&0x07)<<4) | ($str[3]>>4);
        $key[4] = (($str[3]&0x0F)<<3) | ($str[4]>>5);
        $key[5] = (($str[4]&0x1F)<<2) | ($str[5]>>6);
        $key[6] = (($str[5]&0x3F)<<1) | ($str[6]>>7);
        $key[7] = $str[6]&0x7F;
        for $i (0..7) {
                $key[$i] = ($key[$i]<<1);
        }
	return @key;
}
# Ported from SAMBA/source/libsmb/smbdes.c:permute
# Would probably be better to pass in by reference
sub permute {
	my ( @a ) = @_;
	my ( $i, $n, @in, @p, @out );

	# Last argument is the count of the perm values
	$n = $a[$#a];
	@in = @a[0..($#a-$n-1)];
	@p = @_[($#a-$n)..($#a-1)];

	for $i ( 0..($n-1) ) {
		$out[$i] = $in[$p[$i]-1]?1:0;
	}
	return @out;
}

# Ported from SAMBA/source/libsmb/smbdes.c:lshift
# Lazy shifting =)
sub lshift {
	my ( $count, @d ) = @_;
	$count %= ($#d+1);
	@d = (@d,@d)[$count..($#d+$count)];
	return @d;
}

# Ported from SAMBA/source/libsmb/smbdes.c:dohash
sub dohash {
	my ( @a ) = @_;
	my ( @in, @key, $forw, @pk1, @c, @d, @ki, @cd, $i, @pd1, @l, @r, @rl, @out );

	@in = @a[0..63];
	@key = @a[64..($#_-1)];
	$forw = $a[$#a];

	@pk1 = permute( @key, @perm1, 56 );

	@c = @pk1[0..27];
	@d = @pk1[28..55];

	for $i ( 0..15 ) {
		@c = lshift( $sc[$i], @c );
		@d = lshift( $sc[$i], @d );
		
		@cd = map { $_?1:0 } ( @c, @d );
		$ki[$i] = [ permute( @cd, @perm2, 48 ) ];
	}

	@pd1 = permute( @in, @perm3, 64 );

	@l = @pd1[0..31];
	@r = @pd1[32..63];

	for $i ( 0..15 ) {
		my ( $j, $k, @b, @er, @erk, @cb, @pcb, @r2 );
		@er = permute( @r, @perm4, 48 );
		@erk = mxor(@er, @{ @ki[$forw?$i:(15-$i)] });

		for $j ( 0..7 ) {
			for $k ( 0..5 ) {
				$b[$j][$k] = $erk[$j*6 + $k];
			}
		}
		for $j ( 0..7 ) {
			my ( $m, $n );
			$m = ($b[$j][0]<<1) | $b[$j][5];
			$n = ($b[$j][1]<<3) | ($b[$j][2]<<2) | ($b[$j][3]<<1) | $b[$j][4];

			for $k ( 0..3 ) {
				$b[$j][$k]=($sbox[$j][$m][$n] & (1<<(3-$k)))?1:0;
			}
		}
		for $j ( 0..7 ) {
			for $k ( 0..3 ) {
				$cb[$j*4+$k]=$b[$j][$k];
			}
		}
		@pcb = permute( @cb, @perm5, 32);
		@r2 = mxor(@l,@pcb);
		@l = @r[0..31];
		@r = @r2[0..31];
	}
	@rl = ( @r, @l );
	@out = permute( @rl, @perm6, 64 );
	return @out;
}

# Ported from SAMBA/source/libsmb/smbdes.c:smbhash
sub smbhash{
	my ( @in, @key, $forw, @outb, @out, @inb, @keyb, @key2, $i );
	@in = @_[0..7];
	@key = @_[8..14];
	$forw = $_[$#_];

	@key2 = str_to_key(@key);

	for $i ( 0..63 ) {
		$inb[$i] = ( $in[$i/8] & (1<<(7-($i%8)))) ? 1:0;
		$keyb[$i] = ( $key2[$i/8] & (1<<(7-($i%8)))) ? 1:0;
		$outb[$i] = 0;
	}
	@outb = dohash(@inb,@keyb,$forw);
	for $i ( 0..7 ) {
		$out[$i] = 0;
	}
	for $i ( 0..64 ) {
		if ( $outb[$i] )  {
			$out[$i/8] |= (1<<(7-($i%8)));
		}
	}
	return @out;
}

# Ported from SAMBA/source/libsmb/smbdes.c:E_P16
sub E_P16 {
	my ( @p16, @p14, @sp8 );
	@p16 = map { 0 } (1..16);
	@p14 = unpack("C*",$_[0]);
	@sp8 = ( 0x4b, 0x47, 0x53, 0x21, 0x40, 0x23, 0x24, 0x25 );
	@p16 = (smbhash(@sp8,@p14[0..6],1),smbhash(@sp8,@p14[7..13],1));
	return @p16;
}

1;

__END__

=head1 NAME

Crypt::SmbHash - Perl-only implementation of lanman and nt md4 hash functions, for use in Samba style smbpasswd entries

=head1 SYNOPSIS

  use Crypt::SmbHash;

  ntlmgen SCALAR, LMSCALAR, NTSCALAR;

=head1 DESCRIPTION

This module generates Lanman and NT MD4 style password hashes, using
perl-only code for portability. The module aids in the administration
of Samba style systems.

In the Samba distribution, authentication is referred to a private
smbpasswd file. Entries have similar forms to the following:

username:unixuid:LM:NT

Where LM and NT are one-way password hashes of the same password.

ntlmgen generates the hashes given in the first argument, and places
the result in the second and third arguments.

Example:
To generate a smbpasswd entry:

   #!/usr/local/bin/perl 
   use Crypt::SmbHash;
   $username = $ARGV[0];
   $password = $ARGV[1];
   if ( !$password ) {
           print "Not enough arguments\n";
	   print "Usage: $0 username password\n";
	   exit 1;
   }
   $uid = (getpwnam($username))[2];
   my ($login,undef,$uid) = getpwnam($ARGV[0]);
   ntlmgen $password, $lm, $nt;
   printf "%s:%d:%s:%s:[%-11s]:LCT-%08X\n", $login, $uid, $lm, $nt, "U", time;


ntlmgen returns returns the hash values in a list context, so the alternative
method of using it is:

   ( $lm, $nt ) = ntlmgen $password;

The functions lmhash and nthash are used by ntlmgen to generate the
hashes, and are available when requested:

   use Crypt::SmbHash qw(lmhash nthash)
   $lm = lmhash($pass);
   $nt = nthash($pass);

=head1 MD4

The algorithm used in nthash requires the md4 algorithm. This algorithm
is included in this module for completeness, but because it is written
in all-perl code ( rather than in C ), it's not very quick.

However if you have the Digest::MD4 module installed, Crypt::SmbHash will
try to use that module instead, making it much faster.

A simple test compared calling nthash without Digest::MD4 installed, and
with, this showed that using nthash on a system with Digest::MD4 installed
proved to be over 90 times faster.

=head1 AUTHOR

Ported from Samba by Benjamin Kuit <lt>bj@it.uts.edu.au<gt>.

Samba is Copyright(C) Andrew Tridgell 1997-1998

Because this module is a direct port of code within the Samba
distribution, it follows the same license, that is:

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

=cut
