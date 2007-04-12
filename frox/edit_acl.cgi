#!/usr/local/bin/perl
# Show access control options

require './frox-lib.pl';
&ui_print_header(undef, $text{'acl_title'}, "");
$conf = &get_config();

print &ui_form_start("save_acl.cgi", "post");
print &ui_table_start($text{'acl_header'}, "width=100%", 4);

print &config_opt_textbox($conf, "Timeout", 5);

print &config_opt_textbox($conf, "MaxForks", 5);

print &config_opt_textbox($conf, "MaxForksPerHost", 5);

print &config_opt_textbox($conf, "MaxTransferRate", 5, 1, $text{'acl_bps'});

print &config_yesno($conf, "DoNTP", undef, undef, "no");

print &ui_table_row("", "");

print &config_opt_textbox($conf, "NTPAddress", 30, 3, $text{'acl_same'});

print &ui_table_hr();

@acl = &find("ACL", $conf);
$table = "<table border width=100%>\n".
	 "<tr $tb> ".
	 "<td><b>$text{'acl_action'}</b></td> ".
	 "<td><b>$text{'acl_src'}</b></td> ".
	 "<td><b>$text{'acl_dest'}</b></td> ".
	 "<td><b>$text{'acl_ports'}</b></td> ".
         "</tr>\n";
$i = 0;
foreach $a (@acl, { }, { }, { }) {
	$table .= "<tr $cb>\n";
	$table .= "<td>".&ui_select("action_$i",
				    $a->{'words'}->[0],
				    [ [ "", " " ],
				      [ "Allow", $text{'acl_allow'} ],
				      [ "Deny", $text{'acl_deny'} ] ]).
	          "</td>\n";
	$table .= "<td>".&ui_opt_textbox("src_$i",
					 $a->{'words'}->[1] eq "*" ? "" :
						$a->{'words'}->[1],
					 20, $text{'acl_any'})."</td>\n";
	$table .= "<td>".&ui_opt_textbox("dest_$i",
					 $a->{'words'}->[3] eq "*" ? "" :
						$a->{'words'}->[3],
					 20, $text{'acl_any'})."</td>\n";
	$table .= "<td>".&ui_opt_textbox("ports_$i",
					 $a->{'words'}->[4] eq "*" ? "" :
						$a->{'words'}->[4],
					 10, $text{'acl_any'})."</td>\n";
	$table .= "</tr>\n";
	$i++;
	}
$table .= "</table>\n";
print &ui_table_row(undef, $table, 4);

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");

&ui_print_footer("", $text{'index_return'});

