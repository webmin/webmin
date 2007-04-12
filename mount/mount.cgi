#!/usr/local/bin/perl
# mount.cgi
# Mount a currently unmounted filesystem

require './mount-lib.pl';
&ReadParse();

@mounts = &list_mounts();
$mount = $mounts[$in{'index'}];
&error_setup(&text('mount_err', $mount->[0]));
&can_edit_fs(@$mount) || &error($text{'edit_ecannot'});
$err = &mount_dir(@$mount);
&error($err) if ($err);
&webmin_log("mount", undef, undef, { 'dev' => $mount->[0],
				     'type' => $mount->[2],
				     'dir' => $mount->[1] });
&redirect("");

