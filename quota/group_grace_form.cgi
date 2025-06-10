#!/usr/local/bin/perl
# group_grace_form.cgi
# Display a form for editing group grace times for some filesystem

require './quota-lib.pl';
&ReadParse();
$access{'ggrace'} && &can_edit_filesys($in{'filesys'}) ||
	&error($text{'ggracef_ecannot'});
&ui_print_header(undef, $text{'ggracef_title'}, "", "group_grace");

print "$text{'ggracef_info'}<p>\n";

@gr = &get_group_grace($in{'filesys'});
print &ui_form_start("group_grace_save.cgi");
print &ui_hidden("filesys", $in{'filesys'});
print &ui_table_start(&text('ggracef_graces', $in{'filesys'}), undef, 2);

# Block grace time
$bfield = &ui_textbox("btime", $gr[0], 6)." ".
	  &select_grace_units("bunits", $gr[1]);
if (&default_grace()) {
	$bfield = &ui_radio("bdef", $gr[0] ? 0 : 1,
			    [ [ 1, $text{'default'} ],
			      [ 0, $bfield ] ]);
	}
print &ui_table_row($text{'ugracef_block'}, $bfield);

# Files grace time
$ffield = &ui_textbox("ftime", $gr[2], 6)." ".
	  &select_grace_units("funits", $gr[3]);
if (&default_grace()) {
	$ffield = &ui_radio("fdef", $gr[2] ? 0 : 1,
			    [ [ 1, $text{'default'} ],
			      [ 0, $ffield ] ]);
	}
print &ui_table_row($text{'ugracef_file'}, $ffield);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'ugracef_update'} ] ]);

&ui_print_footer("list_groups.cgi?dir=".&urlize($in{'filesys'}),
		 $text{'ggracef_return'});


