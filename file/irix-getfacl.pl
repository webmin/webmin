#!/usr/local/bin/perl
# irix-getfacl.pl
# Wrapper for the ls -D command

$esc = quotemeta($ARGV[0]);
$out = `ls -dDL $esc 2>&1`;
if ($?) {
	print STDERR $out;
	exit 1;
	}
if ($out !~ /\[([^\]]*)\]/) {
	print STDERR "Failed to parse ls -D output : $out\n";
	exit 1;
	}
if ($1) {
	# Convert to normal ACL form
	($acl, $dacl) = split(/\//, $1);
	foreach (split(/,/, $acl)) {
		s/^u:/user:/;
		s/^g:/group:/;
		s/^o:/other:/;
		s/^m:/mask:/;
		print $_,"\n";
		}
	foreach (split(/,/, $dacl)) {
		s/^u:/user:/;
		s/^g:/group:/;
		s/^o:/other:/;
		s/^m:/mask:/;
		print "default:",$_,"\n";
		}
	}
else {
	# Make up ACL from perms
	local @st = stat($ARGV[0]);
	local $other = $st[2] & 7;
	local $group = ($st[2] >> 3) & 7;
	local $user = ($st[2] >> 6) & 7;
	print "user::",&octal_to_perms($user),"\n";
	print "group::",&octal_to_perms($group),"\n";
	print "other::",&octal_to_perms($other),"\n";
	print "mask::",&octal_to_perms($user | $group),"\n";
	}

sub octal_to_perms
{
local $rv;
$rv .= ($_[0] & 4 ? "r" : "-");
$rv .= ($_[0] & 2 ? "w" : "-");
$rv .= ($_[0] & 1 ? "x" : "-");
return $rv;
}

