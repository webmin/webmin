#!/usr/local/bin/perl
# getfacl.cgi
# Gets the ACLs for some file

require './file-lib.pl';
&ReadParse();
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
if (!&can_access($in{'file'})) {
	print $text{'facl_eaccess'},"\n";
	}
else {
	$getfacl = $config{'getfacl'};
	if ($getfacl =~ /^\.\//) {
		$getfacl =~ s/^\./$module_root_directory/;
		}
	chdir("/");
	if ($in{'file'} eq '/') {
		$in{'file'} = '.';
		}
	else {
		$in{'file'} =~ s/^\///;
		}
	$out = &backquote_command($getfacl." ".quotemeta($in{'file'})." 2>&1");
	if ($?) {
		print $out,"\n";
		}
	else {
		foreach $l (split(/\n/, $out)) {
			$l =~ s/#.*$//;
			$l =~ s/\s+$//;
			push(@rv, $l) if ($l =~ /\S/);
			}
		if (!@rv) {
			print "Filesystem does not support ACLs\n";
			}
		else {
			print "\n";
			foreach $l (@rv) {
				print $l,"\n";
				}
			}
		}
	}

