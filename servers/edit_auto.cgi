#!/usr/local/bin/perl
# Show a form for finding Webmin servers
# Thanks to OpenCountry for sponsoring this feature

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';
our (%text, %config, %access, @cluster_modules);
$access{'auto'} || &error($text{'auto_ecannot'});
&ui_print_header(undef, $text{'auto_title'}, "");

print &ui_form_start("save_auto.cgi");
print &ui_table_start($text{'auto_header'}, undef, 2);

my $job = &find_cron_job();
my $mins;
if ($job && $job->{'mins'} =~ /^\*\/(\d+)$/) {
	$mins = $1;
	}
elsif ($job && $job->{'mins'} =~ /^(\d+),(\d+)/) {
	$mins = $2-$1;
	}
elsif ($job && $job->{'mins'} =~ /^(\d+)$/) {
	$mins = 60;
	}
print &ui_table_row($text{'auto_sched'},
    &ui_radio("sched", $job ? 1 : 0,
	      [ [ 0, $text{'no'} ],
		[ 1, &text('auto_sched1', &ui_textbox("mins", $mins, 4)) ] ]));

my @nets = split(/\s+/, $config{'auto_net'});
my $nmode = !$config{'auto_net'} ? 1 :
	    &check_ipaddress($nets[0]) ? 0 : 2;
print &ui_table_row($text{'auto_net'},
    &ui_radio("net_def", $nmode,
	      [ [ 1, $text{'auto_auto'}."<br>" ],
		[ 0, &text('auto_ip', &ui_textbox("net", $nmode == 0 ? $config{'auto_net'} : undef, 40))."<br>" ],
		[ 2, &text('auto_iface', &ui_textbox("iface", $nmode == 2 ? $config{'auto_net'} : undef, 8)) ] ]));

print &ui_table_row($text{'auto_user'},
	    &ui_textbox("auser", $config{'auto_user'}, 20));

print &ui_table_row($text{'auto_pass'},
	    &ui_password("apass", $config{'auto_pass'}, 20));

print &ui_table_row($text{'auto_type'},
	    &ui_select("type", $config{'auto_type'} || "unknown",
		       [ &get_server_types() ]));

print &ui_table_row($text{'auto_email'},
    &ui_opt_textbox("email", $config{'auto_email'}, 20, $text{'auto_none'}));

print &ui_table_row($text{'auto_smtp'},
    &ui_opt_textbox("smtp", $config{'auto_smtp'}, 20, $text{'auto_self'}));

print &ui_table_row($text{'auto_remove'},
	    &ui_yesno_radio("remove", int($config{'auto_remove'})));

print &ui_table_row($text{'auto_findself'},
	    &ui_yesno_radio("self", int($config{'auto_self'})));

foreach my $m (@cluster_modules) {
	if (&foreign_available($m)) {
		print &ui_table_row($text{'auto_'.$m},
			&ui_yesno_radio($m, int($config{'auto_'.$m})));
		}
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

