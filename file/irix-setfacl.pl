#!/usr/local/bin/perl
# irix-setfacl.pl
# Wrapper for the chacl command

while(<STDIN>) {
	s/\r|\n//g;
	$default = ($_ =~ s/^default://);
	s/^(other|mask):([rwx\-]{3})$/\1::\2/g;
	if ($default) {
		push(@dacl, $_);
		}
	else {
		push(@acl, $_);
		}
	}
$esc = quotemeta($ARGV[0]);
$acl = join(",", @acl);
$dacl = join(",", @dacl);
if ($acl && $dacl) {
	$out = `chacl -b $acl $dacl $esc 2>&1`;
	}
elsif ($acl) {
	if (-d $ARGV[0]) {
		$out = `chacl $acl $esc 2>&1 && chacl -D $esc 2>&1`;
		}
	else {
		$out = `chacl $acl $esc 2>&1`;
		}
	}
elsif ($dacl) {
	$out = `chacl -d $dacl $esc 2>&1 && chacl -R $esc 2>&1`;
	}
else {
	$out = `chacl -B $esc 2>&1`;
	}
if ($?) {
	print STDERR $out;
	exit 1;
	}

