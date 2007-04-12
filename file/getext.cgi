#!/usr/local/bin/perl
# getext.cgi
# Returns a string of EXT attributes for some file

require './file-lib.pl';
&ReadParse();
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
if (!&can_access($in{'file'})) {
	print $text{'facl_eaccess'},"\n";
	}
else {
	$out = `lsattr -d '$in{'file'}' 2>&1`;
	$out =~ s/^lsattr.*\n//;
	if ($? || $out !~ /^(\S+)\s/) {
		print $out,"\n";
		}
	else {
		print "\n";
		@a = split(//, $1);
		print join("", grep { $_ ne '-' } @a),"\n";
		}
	}


