#!/usr/local/bin/perl
# Display a form for updating multiple group quotas on a filesystem

require './quota-lib.pl';
&ReadParse();
$fs = $in{'dir'};
@d = split(/\0/, $in{'d'});
foreach $u (@d) {
	&can_edit_group($u) ||
		&error(&text('egroup_eallowgr', $u));
	}
$access{'ro'} && &error(&text('egroup_eallowgr', $u));
&can_edit_filesys($fs) ||
	&error($text{'euser_eallowfs'});
&ui_print_header(undef, $text{'gmass_title'}, "", "edit_group_mass");

$bsize = &block_size($fs);

print &text('gmass_count', scalar(@d)),"<p>\n";
print &ui_form_start("save_group_mass.cgi", "post");
foreach $u (@d) {
	print &ui_hidden("d", $u),"\n";
	}
print &ui_hidden("dir", $fs),"\n";
print &ui_table_start($text{'gmass_header'}, undef, 2);

foreach $t ('sblocks', 'hblocks', 'sfiles', 'hfiles') {
	print &ui_table_row($text{'umass_'.$t},
		&ui_radio($t.'_def', 0,
		 [ [ 0, $text{'umass_leave'} ],
		   [ 1, $text{'umass_unlimited'} ],
		   [ 2, $text{'umass_set'}." ".
			($t =~ /blocks$/ ? &quota_inputbox($t, "", $bsize)
					 : &ui_textbox($t, "", 10)) ] ]));
	}

print &ui_table_end();
print &ui_form_end([ [ "ok", $text{'gmass_ok'} ] ]);

&ui_print_footer("list_groups.cgi?dir=".&urlize($fs), $text{'egroup_greturn'});

