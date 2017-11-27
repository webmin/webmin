#!/usr/local/bin/perl
# run.cgi
# Run some command with the given parameters

require './custom-lib.pl';
$theme_no_table = 1;
if ($ENV{'CONTENT_TYPE'} =~ /multipart\/form-data/i) {
	&ReadParse(\%getin, "GET");
	&ReadParseMime(undef, \&read_parse_mime_callback, [ $getin{'id'} ]);
	}
else {
	&ReadParse();
	}
$| = 1;
&error_setup($text{'run_err'});
$cmd = &get_command($in{'id'}, $in{'idx'});
&can_run_command($cmd) || &error($text{'run_ecannot'});
if (&supports_users()) {
	$user = $cmd->{'user'} eq '*' ? $remote_user : $cmd->{'user'};
	@user_info = getpwnam($user);
	@user_info || &error(&text('run_ecmduser', $user));
	}
else {
	@user_info = ( "root", undef, 0, 0 );
	}

# substitute parameters into command
($env, $export, $str, $displaystr) = &set_parameter_envs(
					$cmd, $cmd->{'cmd'}, \@user_info);

# work out hosts
@hosts = @{$cmd->{'hosts'}};
@hosts = ( 0 ) if (!@hosts);
@servers = &list_servers();

# Run and display output
if ($cmd->{'format'} ne 'redirect' && $cmd->{'format'} ne 'form') {
	if ($cmd->{'format'}) {
		print "Content-type: ",$cmd->{'format'},"\n";
		print "\n";
		}
	else {
		&ui_print_unbuffered_header(
			&html_escape($cmd->{'desc'}), $text{'run_title'},
			"", -d "help" ? "run" : undef);
		}
	}

&remote_error_setup(\&remote_custom_handler);

foreach $h (@hosts) {
	($server) = grep { $_->{'id'} eq $h } @servers;
	next if (!$server);
	$txt = $cmd->{'noshow'} ? 'run_out2' : 'run_out';
	if (@{$cmd->{'hosts'}}) {
		$txt .= 'on';
		}
	if (!$cmd->{'format'}) {
		print &text($txt, "<tt>".&html_escape($displaystr)."</tt>",
		    $server->{'desc'} || "<tt>$server->{'host'}</tt>"),"\n";
		print "<pre>" if (!$cmd->{'raw'});
		}
	$remote_custom_error = undef;
	if ($h == 0) {
		# Run locally
		($got, $out, $timeout) = &execute_custom_command(
					$cmd, $env, $export, $str,
					$cmd->{'format'} ne 'redirect' &&
					$cmd->{'format'} ne 'form');
		}
	else {
		# Remote foreign call
		eval {
			$SIG{'ALRM'} = sub { die "timeout" };
			alarm($cmd->{'timeout'} ? $cmd->{'timeout'} + 5 : 60);
			&remote_foreign_require($server->{'host'}, "custom",
						"custom-lib.pl");
			&remote_foreign_call($server->{'host'}, "custom",
				     "set_parameter_envs", $cmd, $cmd->{'cmd'},
				     \@user_info, \%in, 1);
			($got, $out, $timeout) = &remote_foreign_call(
			   $server->{'host'}, "custom",
			   "execute_custom_command", $cmd, $env, $export, $str);
			};
		if ($@ =~ /timeout/) {
			$timeout = 1;
			}
		alarm(0);
		}
	if ($h == 0) {
		&additional_log('exec', undef, $displaystr);
		}
	if (!$remote_custom_error) {
		print $out if ($h != 0 && $cmd->{'format'} ne 'redirect' &&
					  $cmd->{'format'} ne 'form');
		if (!$got && !$cmd->{'format'}) {
			print "<i>$text{'run_noout'}</i>\n";
			}
		}

	if (!$cmd->{'format'}) {
		print "</pre>\n" if (!$cmd->{'raw'});
		if ($remote_custom_error) {
			print "<b>$remote_custom_error</b><p>\n";
			}
		elsif ($timeout) {
			print "<b>",&text('run_timeout',
					  $cmd->{'timeout'} || 60),"</b><p>\n";
			}
		}

	# Only log non-upload inputs
	%cmdin = ( %$cmd );
	foreach $i (keys %in) {
		($arg) = grep { $_->{'name'} eq $i } @{$cmd->{'args'}};
		if ($arg->{'type'} != 10) {
			$cmdin{$i} = $in{$i};
			}
		}
	}
&webmin_log("exec", "command", $cmd->{'id'}, \%cmdin);
unlink(@unlink) if (@unlink);
if (!$cmd->{'format'}) {
	&ui_print_footer("", $text{'index_return'});
	}
elsif ($cmd->{'format'} eq 'redirect') {
	&redirect("");
	}
elsif ($cmd->{'format'} eq 'form') {
	&redirect("form.cgi?id=".$in{'id'}."&idx=".$in{'idx'});
	}

sub remote_custom_handler
{
$remote_custom_error = join("", @_);
}

