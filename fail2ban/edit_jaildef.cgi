#!/usr/local/bin/perl
# Show a form for default jail options

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text);
&ReadParse();

# Get default jail
my @jails = &list_jails();
my ($jail) = grep { $_->{'name'} eq 'DEFAULT' } @jails;
$jail || &error($text{'jaildef_edef'});

&ui_print_header(undef, $text{'jaildef_title'}, "");

print &ui_form_start("save_jaildef.cgi", "post");
print &ui_table_start($text{'jaildef_header'}, undef, 2);

# Matches needed
my $def_maxretry = 3;
my $maxretry = &find_value("maxretry", $jail);
print &ui_table_row($text{'jail_maxretry'},
	&ui_opt_textbox("maxretry", $maxretry, 6,
			$text{'default'}." (".$def_maxretry.")"));

# Time to scan over
my $def_findtime = 600;
my $findtime = &find_value("findtime", $jail);
print &ui_table_row($text{'jail_findtime'},
	&ui_opt_textbox("findtime", $findtime, 6,
			$text{'default'}." (".$def_findtime.")"));

# Time to ban for
my $def_bantime = 600;
my $bantime = &find_value("bantime", $jail);
print &ui_table_row($text{'jail_bantime'},
	&ui_opt_textbox("bantime", $bantime, 6,
			$text{'default'}." (".$def_bantime.")"));

# IPs to ignore
my $def_ignoreip = "127.0.0.1";
my $ignoreip = &find_value("ignoreip", $jail);
print &ui_table_row($text{'jail_ignoreip'},
	&ui_opt_textbox("ignoreip", $ignoreip, 40,
			$text{'default'}." (".$def_ignoreip.")"));

# Backend to check for file changes
# XXX
my $backend;

# Email destination
# XXX
my $destemail;

# Default ban action
my $banaction;

# Default protocol to ban
my $protocol;

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("list_jails.cgi", $text{'jails_return'});


