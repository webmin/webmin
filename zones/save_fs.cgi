#!/usr/local/bin/perl
# Update, add or delete a filesystem

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
$zinfo = &get_zone($in{'zone'});
$zinfo || &error($text{'edit_egone'});
if (!$in{'new'}) {
	# Find the filesystem object
	($fs) = grep { $_->{'dir'} eq $in{'old'} } @{$zinfo->{'fs'}};
	$fs || &error($text{'fs_egone'});
	$mount = &get_active_mount($zinfo, $fs);
	}
else {
	$fs = { 'keytype' => 'fs',
		'type' => $in{'type'} };
	}

if ($in{'delete'}) {
	# Just remove this filesystem
	&delete_zone_object($zinfo, $fs);

	# Attempt to un-mount it (if mounted)
	if ($mount) {
		&error_setup($text{'fs_err3'});
		&mount::unmount_dir(@$mount);
		}
	}
else {
	# Validate inputs
	$form = &get_fs_form(\%in, $zinfo, $fs, $fs->{'type'});
	$form->validate_redirect("edit_fs.cgi");
	$fs->{'dir'} = $form->get_value("dir");
	if (&indexof($fs->{'type'}, &mount::list_fstypes()) >= 0) {
		# Parse friendly filesystem forms
		$fs->{'special'} = &mount::check_location($fs->{'type'});
		&mount::check_options($fs->{'type'});
		$fs->{'options'} = &mount::join_options($fs->{'type'});
		}
	else {
		# Just use user-entered device and options
		$fs->{'special'} = $form->get_value("special");
		$fs->{'options'} = $form->get_value("options");
		}
	if ($fs->{'special'} =~ /^\/dev\/dsk\/(.*)$/) {
		$fs->{'raw'} = "/dev/rdsk/$1";
		}
	&find_clash($zinfo, $fs) &&
		$form->validate_redirect("edit_fs.cgi",
			[ [ "dir", $text{'fs_eclash'} ] ]);

	# Save the filesystem settings
	$mp = &get_zone_root($zinfo).$fs->{'dir'};
	if ($in{'new'}) {
		&create_zone_object($zinfo, $fs);

		# Attempt to mount it
		if ($in{'mount'}) {
			&error_setup($text{'fs_err2'});
			&system_logged("mkdir -p ".quotemeta($mp));
			&mount::mount_dir($mp,
					  $fs->{'special'},
					  $fs->{'type'},
					  $fs->{'options'});
			}
		}
	else {
		&modify_zone_object($zinfo, $fs);

		# Attempt to re-mount it
		if ($mount) {
			&error_setup($text{'fs_err4'});
			&mount::unmount_dir(@$mount);
			if ($fs->{'dir'} ne $in{'old'}) {
				&system_logged("mkdir -p ".quotemeta($mp));
				}
			print STDERR "mounting $fs->{'special'} on $mp with type $fs->{'type'} and options $fs->{'options'}\n";
			&mount::mount_dir($mp,
					  $fs->{'special'},
					  $fs->{'type'},
					  $fs->{'options'});
			}
		}
	}

&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "fs", $in{'old'} || $fs->{'dir'}, $fs);
&redirect("edit_zone.cgi?zone=$in{'zone'}");

