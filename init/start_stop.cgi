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

# Only allow known init action files
my %ok_files;
foreach my $a (&list_actions()) {
	my ($name) = split(/\s+/, $a);
	my $file = $name =~ /^\// ? $name : "$config{'init_dir'}/$name";
	$ok_files{$file} = 1;
	}
foreach my $rl (&list_runlevels()) {
	foreach my $w ("S", "K") {
		foreach my $a (&runlevel_actions($rl, $w)) {
			my ($order, $name) = split(/\s+/, $a);
			my $file = "$config{'init_base'}/rc$rl.d/$w$order$name";
			$ok_files{$file} = 1 if (-r $file);
			}
		}
	}
$ok_files{$in{'file'}} || &error($text{'ss_ecannot'});
$cmd = quotemeta($in{'file'})." ".quotemeta($action);

# In case the action was Webmin
$SIG{'TERM'} = 'ignore';

# Run the command
print &text('ss_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>";
&clean_environment();
&foreign_call("proc", "safe_process_exec_logged", $cmd, 0, 0, STDOUT, undef, 1);
&reset_environment();
print "</pre>\n";
&webmin_log($action, 'action', $in{'name'});

&ui_print_footer($in{'back'}, $text{'edit_return'});

