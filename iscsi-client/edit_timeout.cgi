#!/usr/local/bin/perl
# Display a page for timeout options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-client-lib.pl';
our (%text);
my $conf = &get_iscsi_config();

&ui_print_header(undef, $text{'timeout_title'}, "");

print &ui_form_start("save_timeout.cgi", "post");
print &ui_table_start($text{'timeout_header'}, undef, 2);

# Session re-establishment timeout
my $timeout = &find_value($conf, "node.session.timeo.replacement_timeout");
my $mode = !defined($timeout) ? 1 :
	   $timeout < 0 ? 2 :
	   $timeout == 0 ? 3 : 0;
print &ui_table_row($text{'timeout_timeout'},
	&ui_radio("timeout_def", $mode,
		[ [ 1, $text{'default'} ],
		  [ 2, $text{'timeout_immediate'} ],
		  [ 3, $text{'timeout_forever'} ],
		  [ 0, $text{'timeout_wait'}." ".
		       &ui_textbox("timeout", $mode == 0 ? $timeout : "", 5).
		       " ".$text{'timeout_secs'} ] ]));

# Other connection timeouts
foreach my $t ("login_timeout", "logout_timeout", "noop_out_interval",
	       "noop_out_timeout") {
	my $v = &find_value($conf, "node.conn[0].timeo.$t");
	print &ui_table_row($text{'timeout_'.$t},
		&ui_opt_textbox($t, $v, 5, $text{'default'})." ".
		$text{'timeout_secs'});
	}

# Other error timeouts
foreach my $t ("abort_timeout", "lu_reset_timeout", "tgt_reset_timeout") {
	my $v = &find_value($conf, "node.session.err_timeo.$t");
	print &ui_table_row($text{'timeout_'.$t},
		&ui_opt_textbox($t, $v, 5, $text{'default'})." ".
		$text{'timeout_secs'});
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


