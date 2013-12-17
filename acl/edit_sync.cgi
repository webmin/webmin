#!/usr/local/bin/perl
# edit_sync.cgi
# Display unix/webmin user synchronization

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access);
$access{'sync'} && $access{'create'} && $access{'delete'} ||
	&error($text{'sync_ecannot'});
&ui_print_header(undef, $text{'sync_title'}, "");

my @glist = &list_groups();
if (!@glist) {
	print "<p>$text{'sync_nogroups'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print &ui_form_start("save_sync.cgi");
print &ui_table_start(undef, undef, 2);

# Sync on creation / deletion
print &ui_table_row($text{'sync_when'},
	&ui_checkbox("create", 1, $text{'sync_create'}, $config{'sync_create'}).
	"<br>\n".
	&ui_checkbox("delete", 1, $text{'sync_delete'}, $config{'sync_delete'}).
	"<br>\n".
	&ui_checkbox("unix", 1, $text{'sync_unix'}, $config{'sync_unix'}));

# Assign new users to group
print &ui_table_row($text{'sync_group'},
	&ui_select("group", $config{'sync_group'},
		   [ map { $_->{'name'} } @glist ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

