#!/usr/local/bin/perl
# mount.cgi
# Mount or un-mount some filesystem
# XXX need way to detect current status?
# XXX should return result
# XXX client must force refresh:
# XXX can only deal with stuff in /etc/fstab

require './file-lib.pl';
$disallowed_buttons{'mount'} && &error($text{'ebutton'});
&ReadParse();
print "Content-type: text/plain\n\n";
if ($access{'ro'} || $access{'uid'}) {
	# User is not allowed to mount
	print "$text{'mount_eaccess'}\n";
	exit;
	}

# Get current status
$dir = &unmake_chroot($in{'dir'});
&foreign_require("mount", "mount-lib.pl");
@fstab = &mount::list_mounts();
@mtab = &mount::list_mounted();
($fstab) = grep { $_->[0] eq $dir } @fstab;
if (!$fstab) {
	# Doesn't exist!
	print "$text{'mount_efstab'}\n";
	exit;
	}
($mtab) = grep { $_->[0] eq $dir } @mtab;

if ($mtab) {
	# Attempt to un-mount now
	$err = &mount::unmount_dir(@$mtab);
	}
else {
	# Attempt to mount now
	$err = &mount::mount_dir(@$fstab);
	}
if ($err) {
	$err =~ s/<[^>]*>//g;
	$err =~ s/\n/ /g;
	print $err,"\n";
	}
else {
	print "\n";
	}

