#!/usr/local/bin/perl
# Show whitelisted and operator users

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config);
&ReadParse();
my $conf = &get_minecraft_config();

&ui_print_header(undef, $text{'users_title'}, "");

my @tabs = ( [ 'white', $text{'users_tabwhite'} ],
	     [ 'op', $text{'users_tabop'} ],
	     [ 'ip', $text{'users_tabip'} ] );
print &ui_tabs_start(\@tabs, 'mode', $in{'mode'} || 'white', 1);

# Whitelisted users
print &ui_tabs_start_tab('mode', 'white');
my @white = &list_whitelist_users();
print &ui_form_start("save_users.cgi", "post");
print &ui_hidden('mode', 'white');
print $text{'users_whitedesc'},"<p>\n";
print &ui_textarea('white', join("\n", @white), 10, 80),"<br>\n";
my $enabled = &find_value("white-list", $conf);
print &ui_checkbox("enabled", 1, $text{'users_enabled'},
		   $enabled =~ /true|yes/i);
print &ui_form_end([ [ undef, $text{'save'} ],
		     [ 'apply', $text{'users_apply'} ] ]);
print &ui_tabs_end_tab('mode', 'white');

# Operator users
print &ui_tabs_start_tab('mode', 'op');
my @op = &list_op_users();
print &ui_form_start("save_users.cgi", "post");
print &ui_hidden('mode', 'op');
print $text{'users_opdesc'},"<p>\n";
print &ui_textarea('op', join("\n", @op), 10, 80);
print &ui_form_end([ [ undef, $text{'save'} ] ]);
print &ui_tabs_end_tab('mode', 'op');

# Banned IPs
print &ui_tabs_start_tab('mode', 'ip');
my @ip = &list_banned_ips();
print &ui_form_start("save_users.cgi", "post");
print &ui_hidden('mode', 'ip');
print $text{'users_ipdesc'},"<p>\n";
print &ui_textarea('ip', join("\n", @ip), 10, 80);
print &ui_form_end([ [ undef, $text{'save'} ] ]);
print &ui_tabs_end_tab('mode', 'ip');

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});
