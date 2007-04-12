#!/usr/local/bin/perl
# unmount.cgi
# Unmount a currently mounted filesystem

require './mount-lib.pl';
&ReadParse();

@mounts = &list_mounted();
$mount = $mounts[$in{'index'}];
&error_setup(&text('unmount_err', $mount->[0]));
&can_edit_fs(@$mount) || &error($text{'edit_ecannot'});
$err = &unmount_dir(@$mount);
&error($err) if ($err);
&delete_unmounted(@$mount);
&webmin_log("umount", undef, undef, { 'dev' => $mount->[0],
				      'type' => $mount->[2],
				      'dir' => $mount->[1] });
&redirect("");

