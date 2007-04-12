#!/usr/local/bin/perl
# getattrs.cgi
# Returns a list in URL-encode name=value format of attributes on some file

require './file-lib.pl';
&ReadParse();
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
if (!&can_access($in{'file'})) {
	print $text{'facl_eaccess'},"\n";
	}
else {
	$out = `attr -l '$in{'file'}' 2>&1`;
	if ($?) {
		print $out,"\n";
		}
	else {
		foreach $l (split(/[\r\n]+/, $out)) {
			if ($l =~ /Attribute\s+"(.*)"/i) {
				# Get the valid for this attribute
				local $name = $1;
				$got = `attr -g '$name' '$in{'file'}' 2>&1`;
				if ($? || $got !~ /^(.*)\n([\0-\377]*)\n$/) {
					print $got,"\n";
					exit;
					}
				push(@rv, [ $name, $2 ] );
				}
			}
		print "\n";
		foreach $r (@rv) {
			print &urlize($r->[0]),"=",&urlize($r->[1]),"\n";
			}
		}
	}

