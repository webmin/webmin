#!/usr/local/bin/perl
# exec_cron.cgi
# Execute an existing cron job, and display the output

require './cron-lib.pl';
&ReadParse();

@jobs = &list_cron_jobs();
$job = $jobs[$in{'idx'}];
&can_edit_user(\%access, $job->{'user'}) || &error($text{'exec_ecannot'});
&foreign_require("proc", "proc-lib.pl");

# split command into command and input
&convert_range($job);
&convert_comment($job);
$job->{'command'} =~ s/\\%/\0/g;
@lines = split(/%/ , $job->{'command'});
foreach (@lines) { s/\0/%/g; }
for($i=1; $i<@lines; $i++) {
	$input .= $lines[$i]."\n";
	}

if ($in{'bg'}) {
	&ui_print_header(undef, $text{'exec_title'}, "");
	}
else {
	&ui_print_unbuffered_header(undef, $text{'exec_title'}, "");
	}
&additional_log('exec', undef, $lines[0]);
&webmin_log("exec", "cron", $job->{'user'}, $job);

# Remove variables that wouldn't be in the 'real' cron
&clean_environment();

# Set cron environment variables
$ENV{'PATH'} = "/usr/bin:/bin"; 
foreach $e (&read_envs($job->{'user'})) {
	$ENV{$1} = $2 if ($e =~ /^(\S+)\s+(.*)$/);
	}

if (&supports_users()) {
	# Get command and switch uid/gid and home directory
	@uinfo = getpwnam($job->{'user'});
	$ENV{"HOME"} = $uinfo[7];
	$ENV{"SHELL"} = "/bin/sh";
	$ENV{"LOGNAME"} = $ENV{"USER"} = $job->{'user'};
	&switch_to_unix_user(\@uinfo);
	chdir($uinfo[7]);
	}

if ($in{'bg'}) {
	# Run in background
	print &text('exec_cmdbg',
		    "<tt>".&html_escape($lines[0])."</tt>"),"<p>\n";
	if (defined($input)) {
		local $temp = &tempname();
		&open_tempfile(TEMP, ">$temp");
		&print_tempfile(TEMP, $input);
		&close_tempfile(TEMP);
		&execute_command("(($lines[0]) ; rm -f $temp) &", $temp,
				 undef, undef);
		}
	else {
		&execute_command("($lines[0]) &", undef, undef, undef);
		}
	}
else {
	# Execute cron command and display output..
	print &text('exec_cmd',
		    "<tt>".&html_escape($lines[0])."</tt>"),"<p>\n";
	print "<pre>";
	$got = &foreign_call("proc", "safe_process_exec",
			     $lines[0], 0, 0, STDOUT, $input, 1);
	print "<i>$text{'exec_none'}</i>\n" if (!$got);
	print "</pre>\n";
	}

&ui_print_footer("edit_cron.cgi?idx=$in{'idx'}", $text{'edit_return'},
	"", $text{'index_return'});

