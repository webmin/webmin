#!/usr/local/bin/perl
# copy.cgi
# Copy some file or directory

require './file-lib.pl';
$disallowed_buttons{'copy'} && &error($text{'ebutton'});
&ReadParse();
&webmin_log("copy", undef, $in{'from'}, \%in);
print "Content-type: text/plain\n\n";
if ($access{'ro'} || !&can_access($in{'from'})) {
	print &text('copy_efrom', $in{'from'}),"\n";
	exit;
	}
if (!&can_access($in{'to'})) {
	print &text('copy_eto', $in{'to'}),"\n";
	exit;
	}
if (-l &unmake_chroot($in{'from'})) {
	# Remake the link
	&switch_acl_uid_and_chroot();
	&lock_file($in{'to'});
	if (!symlink(readlink($in{'from'}), $in{'to'})) {
		print &text('copy_elink', $!),"\n";
		exit;
		}
	&unlock_file($in{'to'});
	$err = undef;
	$info = $in{'to'};
	}
else {
	&switch_acl_uid();
	($ok, $err) = &copy_source_dest(&unmake_chroot($in{'from'}), &unmake_chroot($in{'to'}));
	$err = undef if ($ok);
	$info = &unmake_chroot($in{'to'});
	}
if ($err) {
	print $err,"\n";
	}
else {
	print "\n";
	print &file_info_line($info),"\n";
	}

sub split_dir
{
$_[0] =~ /^(.*\/)([^\/]+)$/;
return ($1, $2);
}

