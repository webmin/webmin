#!/usr/local/bin/perl
# delete_zone.cgi
# Delete an existing view and all its zones

require './bind8-lib.pl';
&ReadParse();
$pconf = &get_config_parent();
$conf = $pconf->{'members'};
$vconf = $conf->[$in{'index'}];
$access{'views'} || &error($text{'view_ecannot'});

if (!$in{'confirm'}) {
	# Ask the user if he is sure ..
	&ui_print_header(undef, $text{'vdelete_title'}, "");

	@zones = &find("zone", $vconf->{'members'});
	print "<center><p>",&text(@zones ? 'vdelete_mesg' : 'vdelete_mesg2',
				  "<tt>$vconf->{'value'}</tt>"),"<p>\n";
	print "<form action=delete_view.cgi>\n";
	print "<input type=hidden name=index value=$in{'index'}>\n";
	print "<input type=submit name=confirm value='$text{'delete'}'><br>\n";
	if (@zones) {
		print "<b>$text{'vdelete_newview'}</b>\n";
		print "<input type=radio name=mode value=0> ",
		      "$text{'vdelete_delete'}\n";
		print "<input type=radio name=mode value=1 checked> ",
		      "$text{'vdelete_root'}\n";
		@views = &find("view", $conf);
		if (@views > 1) {
			print "<input type=radio name=mode value=2> ",
			      "$text{'vdelete_move'}\n";
			print "<select name=newview>\n";
			foreach $v (@views) {
				if ($v->{'index'} != $in{'index'}) {
					printf "<option value=%d>%s\n",
						$v->{'index'}, $v->{'value'};
					}
				}
			print "</select>\n";
			}
		print "<br>\n";
		}
	print "</form></center>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# deal with the zones in this view
@zones = &find("zone", $vconf->{'members'});
if ($in{'mode'} == 1) {
	$dest = $pconf;
	}
else {
	$dest = $conf->[$in{'newview'}];
	}
&lock_file(&make_chroot($dest->{'file'}));
foreach $z (@zones) {
	local $type = &find_value("type", $z->{'members'});
	next if (!$type || $type eq 'hint');
	if ($in{'mode'} == 0) {
		# Delete the records file
		local $file = &find_value("file", $z->{'members'});
		if ($file) {
			&lock_file(&make_chroot(&absolute_path($file)));
			unlink(&make_chroot(&absolute_path($file)));
			}
		}
	else {
		# Move to another view or the top level
		&save_directive($dest, undef, [ $z ], $in{'mode'} == 2 ? 1 : 0);
		}
	}
&flush_file_lines();

# remove the view directive
&lock_file(&make_chroot($vconf->{'file'}));
$lref = &read_file_lines(&make_chroot($vconf->{'file'}));
splice(@$lref, $vconf->{'line'}, $vconf->{'eline'} - $vconf->{'line'} + 1);
&flush_file_lines();
&unlock_all_files();
&webmin_log("delete", "view", $vconf->{'value'}, \%in);
&redirect("");

