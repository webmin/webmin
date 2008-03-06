#!/usr/local/bin/perl
# Show a form for editing or creating a template

require './status-lib.pl';
$access{'edit'} || &error($text{'tmpls_ecannot'});
&ReadParse();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'tmpl_title1'}, "");
	$tmpl = { };
	}
else {
	&ui_print_header(undef, $text{'tmpl_title2'}, "");
	$tmpl = &get_template($in{'id'});
	}

# Collapsible section with instructions
print &ui_hidden_start($text{'tmpl_instr'}, 'instr', 0,
		       "edit_tmpl.cgi?new=$in{'new'}&id=$in{'id'}");
print $text{'tmpl_subs'},"<p>\n";
print "<table>\n";
foreach $s ('DESC', 'HOST', 'DATE', 'TIME', 'STATUS') {
	print "<tr> <td><tt>\$\{$s\}</tt></td>\n";
	print "<td>",$text{'tmpl_subs_'.lc($s)},"</td> </tr>\n";
	}
print "</table>\n";
print &text('tmpl_subs2', '${IF-DOWN}', '${ELSE-DOWN}', '${ENDIF-DOWN}'),
      "<br>\n";
print &ui_hidden_end();

# Start of form
print &ui_form_start("save_tmpl.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'tmpl_header'}, "width=100%", 2);

# Description of this template
print &ui_table_row($text{'tmpl_desc'},
	&ui_textbox("desc", $tmpl->{'desc'}, 60));

# Email message
print &ui_table_row($text{'tmpl_email'},
	&ui_textarea("email", $tmpl->{'email'}, 5, 60));

# SMS / pager message
print &ui_table_row($text{'tmpl_sms'},
	&ui_radio("sms_def", $tmpl->{'sms'} ? 0 : 1,
		  [ [ 1, $text{'tmpl_sms1'} ], [ 0, $text{'tmpl_sms0'} ] ]).
	"<br>\n".
	&ui_textarea("sms", $tmpl->{'sms'}, 3, 60));

# SNMP message
print &ui_table_row($text{'tmpl_snmp'},
	&ui_opt_textbox("snmp", $tmpl->{'snmp'}, 50, $text{'tmpl_sms1'}));

# Save buttons
print &ui_table_end();
print &ui_form_end($in{'new'} ?
		[ [ undef, $text{'create'} ] ] :
	        [ [ undef, $text{'save'} ], [ 'delete', $text{'delete'} ] ]);

&ui_print_footer("list_tmpls.cgi", $text{'tmpls_return'});

