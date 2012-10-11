#!/usr/local/bin/perl
# Show global authentication options

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text);
my $conf = &get_iscsi_config();

&ui_print_header(undef, $text{'auth_title'}, "");

print &ui_form_start("save_auth.cgi", "post");
print &ui_table_start($text{'auth_header'}, undef, 2);

# Incoming user(s)
my @iusers = &find_value($conf, "IncomingUser");
my $utable = &ui_columns_start([
		$text{'target_uname'},
		$text{'target_upass'},
		]);
my $i = 0;
foreach my $u (@iusers, "", "") {
	my ($uname, $upass) = split(/\s+/, $u);
	$utable .= &ui_columns_row([
		&ui_textbox("uname_$i", $uname, 30),
		&ui_textbox("upass_$i", $upass, 20),
		]);
	$i++;
	}
$utable .= &ui_columns_end();
print &ui_table_row($text{'auth_iuser'},
	&ui_radio("iuser_def", @iusers ? 0 : 1,
		  [ [ 1, $text{'target_iuserall'} ],
		    [ 0, $text{'target_iuserbelow'} ] ])."<br>\n".
	$utable);

# Outgoing user
my $u = &find_value($conf, "OutgoingUser");
my ($uname, $upass) = split(/\s+/, $u);
print &ui_table_row($text{'auth_ouser'},
	&ui_radio("ouser_def", $u ? 0 : 1,
		  [ [ 1, $text{'target_ousernone'} ],
		    [ 0, $text{'target_ousername'} ] ])." ".
	&ui_textbox("ouser", $uname, 30)." ".
	$text{'target_ouserpass'}." ".
	&ui_textbox("opass", $upass, 20));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
