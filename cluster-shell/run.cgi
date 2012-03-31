#!/usr/local/bin/perl
# run.cgi
# Actually run the command on all servers and show the output

require './cluster-shell-lib.pl';
&ReadParse();
&error_setup($text{'run_err'});

if ($in{'clear'}) {
	# Just clearing history
	&lock_file($commands_file);
	unlink($commands_file);
	&unlock_file($commands_file);
	&webmin_log("clear");
	&redirect("");
	exit;
	}

$in{'cmd'} ||= $in{'old'};
$in{'cmd'} =~ /\S/ || &error($text{'run_ecmd'});

# Build the list of servers
@servers = &servers::list_servers();
@sel = split(/\0/, $in{'server'});
foreach $s (@sel) {
	if ($s eq "ALL") {
		push(@run, grep { $_->{'user'} } @servers);
		}
	elsif ($s =~ /^group_(.*)$/) {
		# All members of a group
		($group) = grep { $_->{'name'} eq $1 }
				&servers::list_all_groups(\@servers);
		foreach $m (@{$group->{'members'}}) {
			push(@run, grep { $_->{'host'} eq $m && $_->{'user'} }
					@servers);
			}
		}
	elsif ($s eq '*') {
		# This server
		push(@run, ( { 'desc' => $text{'index_this'} } ));
		}
	else {
		# A single remote server
		push(@run, grep { $_->{'host'} eq $s } @servers);
		}
	}
@run = grep { !$done{$_->{'id'}}++ } @run;
@run || &error($text{'run_enone'});

&ui_print_header(undef, $text{'run_title'}, "");

# Setup error handler for down hosts
sub inst_error
{
$inst_error_msg = join("", @_);
}
&remote_error_setup(\&inst_error);

# Run one each one in parallel and display the output
$p = 0;
foreach $s (@run) {
	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	select($wh); $| = 1; select(STDOUT);
	if (!fork()) {
		# Run the command in a subprocess
		close($rh);

		&remote_foreign_require($s->{'host'}, "webmin",
					"webmin-lib.pl");
		if ($inst_error_msg) {
			# Failed to contact host ..
			print $wh &serialise_variable([ 0, $inst_error_msg ]);
			exit;
			}

		# Run the command and capture output
		local $q = quotemeta($in{'cmd'});
		local $rv = &remote_eval($s->{'host'}, "webmin",
					 "\$x=`($q) </dev/null 2>&1`");

		print $wh &serialise_variable([ 1, $rv ]);
		close($wh);
		exit;
		}
	close($wh);
	$p++;
	}

# Get back all the results
$p = 0;
foreach $s (@run) {
	local $rh = "READ$p";
	local $line = <$rh>;
	close($rh);
	local $rv = &unserialise_variable($line);

	local $d = $s->{'host'}.($s->{'desc'} ? " (".$s->{'desc'}.")" : "");

	if (!$line) {
		# Comms error with subprocess
		print "<b>",&text('run_failed', $d, "Unknown reason"),
		      "</b><p>\n";
		}
	elsif (!$rv->[0]) {
		# Error with remote server
		print "<b>",&text('run_failed', $d, $rv->[1]),"</b><p>\n";
		}
	else {
		# Done - show output
		print "<b>",&text('run_success', $d),"</b>\n";
		print "<ul><pre>".&html_escape($rv->[1])."</pre></ul><p>\n";
		}
	$p++;
	}

# Save command and server
&open_lock_tempfile(COMMANDS, ">>$commands_file");
&print_tempfile(COMMANDS, $in{'cmd'},"\n");
&close_tempfile(COMMANDS);
$config{'server'} = join(" ", @sel);
&save_module_config();

&webmin_log("run", undef, undef, { 'cmd' => $in{'cmd'},
				   'run' => [ map { $_->{'host'} } @run ] });

&ui_print_footer("", $text{'index_return'});

