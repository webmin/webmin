#!/usr/local/bin/perl
# edit_mount.cgi
# Display a form for editing or creating a permanent or temporary mounting.

require './mount-lib.pl';
&error_setup($text{'edit_err'});
&ReadParse();
if (defined($in{index})) {
	if ($in{temp}) {
		# Edit a temporary mount, existing only in the mnttab
		@mlist = &list_mounted();
		@minfo = @{$mlist[$in{index}]};
		$mnow = 1; $msave = 0;
		}
	else {
		# Edit a permanent mount, which may or may not be currently
		# mounted.
		@mlist = &list_mounts();
		@minfo = @{$mlist[$in{index}]};
		$msave = 1; $mnow = (&get_mounted($minfo[0], $minfo[1]) >= 0);
		}
	if ($in{index} >= @mlist) {
		&error($text{'edit_egone'});
		}
	&can_edit_fs(@minfo) && !$access{'only'} ||
		&error($text{'edit_ecannot'});
	$type = $minfo[2];
	&ui_print_header(undef, $text{'edit_title'}, "");
	$newm = 0;
	}
else {
	# creating a new mount (temporary or permanent)
	$type = $in{type};
	&ui_print_header(undef, $text{'create_title'}, "");
	$newm = 1;
	}
@mmodes = &mount_modes($type);
$msave = ($mmodes[0]==0 ? 0 : $msave);
$mnow = ($mmodes[1]==0 ? $msave : $mnow);

# Start of the form
print &ui_form_start("save_mount.cgi", "post");
print &ui_hidden("return", $in{'return'});
if (!$newm) {
	print &ui_hidden("old", $in{'index'});
	print &ui_hidden("temp", $in{'temp'});
	print &ui_hidden("oldmnow", $mnow);
	print &ui_hidden("oldmsave", $msave);
	}
print &ui_hidden("type", $type);
print &ui_table_start(&text('edit_header', &fstype_name($type)),
		      "width=100%", 2, [ "width=20%" ]);

# Mount point
if ($type eq "swap") {
	$mfield = "<i>$text{'edit_swap'}</i>";
	}
else {
	local $dir = $minfo[0] || $in{'newdir'};
	if (@access_fs == 1) {
		# Make relative to first allowed dir
		$dir =~ s/^$access_fs[0]\///;
		}
	$mfield = &ui_textbox("directory", $dir, 40);
	if ($access{'browse'}) {
		$mfield .= " ".&file_chooser_button("directory", 1);
		}
	}
print &ui_table_row(&hlink($text{'edit_dir'}, "edit_dir"),
		    $mfield);

# Total and free space
if (!$newm) {
	($size,$free) = &disk_space($type, $minfo[0]);
	if ($size) {
		print &ui_table_row($text{'edit_usage'},
			"<b>$text{'edit_size'}</b> ".
			&nice_size($size*1024)." ".
			"<b>$text{'edit_free'}</b> ".
			&nice_size($free*1024));
		}
	}

# Show save mount options
if ($mmodes[0] != 0) {
	@opts = ( [ 2, $text{'edit_boot'} ] );
	if ($mmodes[0] != 1) {
		push(@opts, [ 1, $text{'edit_save'} ]);
		}
	if (!$newm && $mmodes[1] == 0) {
		push(@opts, [ 0, $text{'edit_delete'} ]);
		}
	else {
		push(@opts, [ 0, $text{'edit_dont'} ]);
		}
	print &ui_table_row($text{'edit_savemount'},
		&ui_radio("msave", $minfo[5] eq "yes" || $newm ? 2 :
				   $minfo[5] eq "no" ? 1 :
				   $minfo[5] eq "" && !$newm ? 0 : undef,
			  \@opts));
	}

# Show mount now options
if ($mmodes[1] == 1 && ($mmodes[3] == 0 || !$mnow)) {
	print &ui_table_row($text{'edit_now'},
		&ui_radio("mmount", $mnow || $newm ? 1 : 0,
			  [ [ 1, $text{'edit_mount'} ],
			    [ 0, $mmodes[0] == 0 ? $text{'edit_delete'} :
				 $newm ? $text{'edit_dont2'} :
					 $text{'edit_unmount'} ] ]));
	}

# Show fsck order options
if ($mmodes[2]) {
	$second = $minfo[4] > 1 ? $minfo[4] : 2;
	print &ui_table_row($text{'edit_order'},
		&ui_radio("order", $newm || $minfo[4] == 0 ? 0 :
				   $minfo[4] == 1 ? 1 :
				   $second,
			  [ [ 0, $text{'no'} ],
			    [ 1, $text{'edit_first'} ],
			    [ $second, $text{'edit_second'} ] ]));
	}

# Show filesystem-specific mount source
&generate_location($type, $minfo[1] || $in{'newdev'});
print &ui_table_end();

if (!defined($access{'opts'}) || $access{'opts'} =~ /$type/) {
	# generate mount options
	print &ui_table_start($text{'edit_adv'}, "width=100%", 4,
			      [ "width=20%" ]);
	&parse_options($type, $minfo[3]);
	&generate_options($type, $newm);
	print &ui_table_end();
	}

# Save and other buttons
if ($newm) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
elsif ($mnow && $minfo[2] ne "swap") {
	&foreign_require("proc");
	print &ui_hidden("lsoffs", $minfo[0]);
	print &ui_form_end([ [ undef, $text{'save'} ],
			     $proc::has_fuser_command ?
				( [ 'lsof', $text{'edit_list'} ] ) : ( ) ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}

&ui_print_footer($in{'return'}, $text{'index_return'});

