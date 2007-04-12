#!/usr/local/bin/perl
# setattrs.cgi
# Sets all the XFS attributes for a file

require './file-lib.pl';
$disallowed_buttons{'attr'} && &error($text{'ebutton'});
&ReadParse();
&webmin_log("attr", undef, $in{'file'}, \%in);
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
if ($access{'ro'} || !&can_access($in{'file'})) {
	print $text{'facl_eaccess'},"\n";
	}
else {
	# Set given attribs
	$temp = &transname();
	for($i=0; defined($n = $in{"name$i"}); $i++) {
		$v = $in{"value$i"};
		open(TEMP, ">$temp");
		print TEMP $v;
		close(TEMP);
		$out = `attr -s '$n' '$in{'file'}' <$temp 2>&1`;
		unlink($temp);
		if ($?) {
			print $out,"\n";
			exit;
			}
		$set{$n}++;
		}

	# Remove those that no longer exist
	$out = `attr -l '$in{'file'}' 2>&1`;
	foreach $l (split(/[\r\n]+/, $out)) {
		if ($l =~ /Attribute\s+"(.*)"/i && !$set{$1}) {
			$out = `attr -r '$1' '$in{'file'}' 2>&1`;
			if ($?) {
				print $out,"\n";
				exit;
				}
			}
		}
	print "\n";
	}

