#!/usr/local/bin/perl
# size.cgi
# Returns the size in bytes, number of files and number of dirs in a directory

require './file-lib.pl';
&ReadParse();
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
if (!&can_list($in{'dir'})) {
	print $text{'list_eaccess'},"\n";
	}
($size, $files, $dirs) = &recursive_dir_info($in{'dir'});
print "\n";
print $size," ",$files," ",$dirs," ",&nice_size($size),"\n";

# recursive_dir_info(directory)
sub recursive_dir_info
{
local $dir = &translate_filename($_[0]);
if (-l $dir) {
	# Symlink
	return (0, 1, 0);
	}
elsif (-f $dir) {
	local @st = stat($dir);
	return ($st[7], 1, 0);
	}
elsif (-d $dir) {
	local @st = stat($dir);
	local ($size, $files, $dirs) = ($st[7], 0, 1);
	opendir(DIR, $dir);
	local @files = readdir(DIR);
	closedir(DIR);
	foreach my $f (@files) {
		next if ($f eq "." || $f eq "..");
		local @r = &recursive_dir_info("$dir/$f");
		$size += $r[0];
		$files += $r[1];
		$dirs += $r[2];
		}
	return ($size, $files, $dirs);
	}
else {
	# Special file ..
	return (0, 1, 0);
	}
}


