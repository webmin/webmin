#!/usr/local/bin/perl
# chmod.cgi
# Change the ownership and permissions on a file

require './file-lib.pl';
$disallowed_buttons{'info'} && &error($text{'ebutton'});
&ReadParse();
&webmin_log($in{'linkto'} ? "relink" : "chmod", undef, $in{'path'}, \%in);
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
!$access{'ro'} && &can_access($in{'path'}) ||
	&failure(&text('chmod_eaccess', $in{'path'}));

if (defined($in{'user'})) {
	$uid = $in{'user'} =~ /^\d+$/ ? $in{'user'} :
	       %user_to_uid ? $user_to_uid{$in{'user'}} :
			      getpwnam($in{'user'});
	&failure(&text('chmod_euser', $in{'user'})) if (!defined($uid));
	$gid = $in{'group'} =~ /^\d+$/ ? $in{'group'} :
	       %group_to_gid ? $group_to_gid{$in{'group'}} :
			       getgrnam($in{'group'});
	&failure(&text('chmod_egroup', $in{'group'})) if (!defined($gid));
	}

if ($in{'linkto'}) {
	# Just changing the link target
	$follow && &failure($text{'chmod_efollow'});
	&lock_file($in{'path'});
	unlink($in{'path'});
	symlink($in{'linkto'}, $in{'path'}) ||
		&failure(&text('chmod_elink', $1));
	&unlock_file($in{'path'});
	}
elsif ($in{'rec'} == 0) {
	# Just this file
	&update($in{'path'}, 0);
	}
elsif ($in{'rec'} == 1) {
	# This directory and all its files
	&update($in{'path'}, 0);
	opendir(DIR, $in{'path'});
	foreach $f (readdir(DIR)) {
		next if ($f eq "." || $f eq "..");
		next if (-l $full);
		&update("$in{'path'}/$f", 1) if (!-d $full);
		}
	closedir(DIR);
	}
elsif ($in{'rec'} == 2) {
	# Directory and all subdirectories and files
	&update($in{'path'}, 0);
	&recurse($in{'path'}, 1, 1);
	}
elsif ($in{'rec'} == 3) {
	# Files in the directory and sub-directories, but not the directories
	# themselves
	&recurse($in{'path'}, 1, 0);
	}
elsif ($in{'rec'} == 4) {
	# This directory and sub-directories, but not files
	&update($in{'path'}, 0);
	&recurse($in{'path'}, 0, 1);
	}
print "\n";

# recurse(dir, do-files, do-dirs)
# Updates permissions on all files in a directory, and sub-directories
sub recurse
{
local ($dir, $do_files, $do_dirs) = @_;
opendir(DIR, $_[0]);
my @files = readdir(DIR);
closedir(DIR);
foreach my $f (@files) {
	my $full = "$dir/$f";
	next if ($f eq "." || $f eq "..");
	next if (-l $full);
	if (!-d $full && $do_files ||
	    -d $full && $do_dirs) {
		&update($full, !-d $full);
		}
	&recurse($full, $do_files, $do_dirs) if (-d $full);
	}
}

sub failure
{
print @_,"\n";
exit;
}
 
# update(file, perms_only)
# Update permissions and ownership on a single file
sub update
{
local $perms = $in{'perms'};
if (defined($uid)) {
	chown($uid, $gid, $_[0]) || &failure(&text('chmod_echown', $!));
	}
if (defined($perms)) {
	if ($_[1]) {
		@st = stat($_[0]);
		$perms = ($perms & 07777) | ($st[2] & 037777770000);
		}
	chmod($perms, $_[0]) || &failure(&text('chmod_echmod', $!));
	}
}

