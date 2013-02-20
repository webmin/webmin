#!/usr/local/bin/perl
# start_stop.cgi
# Start or stop a boot-time action

require './init-lib.pl';
&foreign_require("proc", "proc-lib.pl");
$access{'bootup'} || &error($text{'ss_ecannot'});
&ReadParse();

# Work out the correct command, and show header
$| = 1;
$theme_no_header = 1;
foreach $a ('start', 'restart', 'condrestart', 'reload', 'status', 'stop') {
	if (defined($in{$a})) {
		$action = $a;
		}
	}
$action ||= 'stop';
&ui_print_header(undef, $text{'ss_'.$action}, "");
$cmd = $in{'file'}." ".$action;

# In case the action was Webmin
$SIG{'TERM'} = sub { };

# Run the command
print &text('ss_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>";
&clean_environment();
&foreign_call("proc", "safe_process_exec_logged", $cmd, 0, 0, STDOUT, undef, 1);
&reset_environment();
print "</pre>\n";
&webmin_log($action, 'action', $in{'name'});

&ui_print_footer($in{'back'}, $text{'edit_return'});

