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
	       defined(%user_to_uid) ? $user_to_uid{$in{'user'}} :
				       getpwnam($in{'user'});
	&failure(&text('chmod_euser', $in{'user'})) if (!defined($uid));
	$gid = $in{'group'} =~ /^\d+$/ ? $in{'group'} :
	       defined(%group_to_gid) ? $group_to_gid{$in{'group'}} :
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
	# Directory and all subdirectories
	&update($in{'path'}, 0);
	&recurse($in{'path'});
	}
print "\n";

sub recurse
{
local(@files, $f, $full);
opendir(DIR, $_[0]);
@files = readdir(DIR);
closedir(DIR);
foreach $f (@files) {
	$full = "$_[0]/$f";
	next if ($f eq "." || $f eq "..");
	next if (-l $full);
	&update($full, !-d $full);
	&recurse($full) if (-d $full);
	}
}

sub failure
{
print @_,"\n";
exit;
}
 
# update(file, perms_only)
sub update
{
local $perms = $in{'perms'};
if (defined($perms)) {
	if ($_[1]) {
		@st = stat($_[0]);
		$perms = ($perms & 0777) | ($st[2] & 037777777000);
		}
	chmod($perms, $_[0]) || &failure(&text('chmod_echmod', $!));
	}
if (defined($uid)) {
	chown($uid, $gid, $_[0]) || &failure(&text('chmod_echown', $!));
	}
}

