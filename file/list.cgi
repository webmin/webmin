#!/usr/local/bin/perl
# list.cgi
# Return a list of files in some directory

require './file-lib.pl';
&ReadParse();
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
$d = $in{'dir'} eq "/" ? "" : $in{'dir'};
if (!&can_list($in{'dir'})) {
	print $text{'list_eaccess'},"\n";
	}
elsif (!opendir(DIR, $in{'dir'})) {
	# Cannot list the dir .. but maybe we don't have to!
	# If a sub-directory was requested, just assume that it exists.
	local $err = $!;
	local @alt = &accessible_subdir($in{'dir'});
	local $fil = &file_info_line($in{'dir'});
	if (@alt && $fil) {
		print "\n";
		foreach $f ("$in{'dir'}/.", "$in{'dir'}/..", @alt) {
			$fil = &file_info_line($f);
			print "$fil\n" if (defined($fil));
			}
		}
	else {
		print "$err\n";
		}
	}
else {
	# Can list the directory
	print "\n";
	@files = sort { lc($a) cmp lc($b) } readdir(DIR);
	if ($hide_dot_files) {
		@files = grep { $_ !~ /^\./ } @files;
		}
	else {
		@files = grep { $_ ne "." && $_ ne ".." } @files;
		}
	@files = grep { &can_list("$d/$_") } @files;
	closedir(DIR);
	foreach $f (".", "..", @files) {
		local $fil = &file_info_line("$d/$f");
		print "$fil\n" if (defined($fil));
		}
	}

