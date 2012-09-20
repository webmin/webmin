#!/usr/local/bin/perl
# Display a page for iscsi options

use strict;
use warnings;
require './iscsi-client-lib.pl';
our (%text);
my $conf = &get_iscsi_config();

&ui_print_header(undef, $text{'iscsi_title'}, "");

print &ui_form_start("save_iscsi.cgi", "post");
print &ui_table_start($text{'iscsi_header'}, undef, 2);

# Start sessions at boot?
my $startup = &find_value($conf, "node.startup");
print &ui_table_row($text{'iscsi_startup'},
	&ui_yesno_radio("startup", $startup eq "automatic" ? 1 : 0));

# Login re-try limit
my $retry = &find_value($conf, "node.session.initial_login_retry_max");
print &ui_table_row($text{'iscsi_retry'},
	&ui_opt_textbox("retry", $retry, 5, $text{'default'}));

# Max commands in session queue
my $cmds = &find_value($conf, "node.session.cmds_max");
print &ui_table_row($text{'iscsi_cmds'},
	&ui_opt_textbox("cmds", $cmds, 5, $text{'default'}));

# Device queue depth
my $queue = &find_value($conf, "node.session.queue_depth");
print &ui_table_row($text{'iscsi_queue'},
	&ui_opt_textbox("queue", $queue, 5, $text{'default'}));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


