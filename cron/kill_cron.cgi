#!/usr/local/bin/perl
# Terminate a running cron job

require './cron-lib.pl';
&ReadParse();
&error_setup($text{'kill_err'});

@jobs = &list_cron_jobs();
$job = $jobs[$in{'idx'}];
&can_edit_user(\%access, $job->{'user'}) || &error($text{'kill_ecannot'});
$proc = &find_cron_process($job);
$proc || &error($text{'kill_egone'});

if (!$in{'confirm'}) {
	# Ask first
	&ui_print_header(undef, $text{'kill_title'}, "");
	print &ui_form_start("kill_cron.cgi");
	print &ui_hidden("idx", $in{'idx'}),"\n";
	print "<center>",&text($config{'kill_subs'} ? 'kill_rusure2'
						    : 'kill_rusure',
		       "<tt>$proc->{'args'}</tt>", $proc->{'pid'}),"<p>\n";
	print &ui_submit($text{'kill_ok'}, "confirm");
	print "</center>\n";
	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Do it!
	@tokill = ( $proc->{'pid'} );
	if ($config{'kill_subs'}) {
		push(@tokill, map { $_->{'pid'} }
			      &proc::find_subprocesses($proc));
		}
	&kill_logged('TERM', @tokill) || &error(&text('kill_ekill', $!));
	&webmin_log("kill", "cron", $job->{'user'}, $job);
	&redirect("");
	}

