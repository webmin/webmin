#!/usr/local/bin/perl
# edit_aserv.cgi
# Edit <Anonymous> section details

require './proftpd-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
$desc = $in{'virt'} eq '' ? $text{'anon_header2'} :
	      &text('anon_header1', $v->{'value'});
if (!$in{'init'}) {
	$anon = &find_directive_struct("Anonymous", $conf);
	&ui_print_header($desc, $text{'aserv_title'}, "",
		undef, undef, undef, undef, &restart_button());
	}
else {
	&ui_print_header($desc, $text{'aserv_create'}, "",
		undef, undef, undef, undef, &restart_button());
	}

print $text{'aserv_desc'},"<br>\n" if ($in{'init'});

$user = &find_directive("User", $anon->{'members'});
$user ||= "ftp" if ($in{'init'});
$group = &find_directive("Group", $anon->{'members'});
$group ||= "ftp" if ($in{'init'});

print &ui_form_start("save_aserv.cgi", "post");
print &ui_hidden("virt", $in{'virt'});
print &ui_hidden("init", $in{'init'});
print &ui_table_start($text{'aserv_title'}, undef, 2);

print &ui_table_row($text{'aserv_root'},
	&ui_filebox("root", $anon->{'value'}, 60, 0, undef, undef, 1));

print &ui_table_row($text{'aserv_user'},
	&opt_input($user, "User", $text{'default'}, 13));

print &ui_table_row($text{'aserv_group'},
	&opt_input($group, "Group", $text{'default'}, 13));

print &ui_table_end();
print &ui_form_end([ [ undef, $in{'init'} ? $text{'create'} : $text{'save'} ]]);

if ($in{'init'}) {
	&ui_print_footer(
		"virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
		"", $text{'index_return'});
	}
else {
	&ui_print_footer(
		"anon_index.cgi?virt=$in{'virt'}", $text{'anon_return'},
		"virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
		"", $text{'index_return'});
	}

