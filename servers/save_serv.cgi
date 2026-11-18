#!/usr/local/bin/perl
# save_serv.cgi
# Save or delete a server

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';
our (%in, %access, %text, %config, $remote_error_handler);
&ReadParse();
$access{'edit'} || &error($text{'edit_ecannot'});
&error_setup($text{'save_err'});

my $serv;
if ($in{'id'}) {
	$serv = &get_server($in{'id'});
	&can_use_server($serv) || &error($text{'edit_ecannot'});
	}
else {
	$access{'add'} || &error($text{'edit_ecannot'});
	$serv = { 'id' => time() };
	}
my $oldmode = !$in{'id'} ? $config{'deflink'} :
	      $serv->{'autouser'} ? 2 :
	      $serv->{'sameuser'} ? 3 : $serv->{'user'} ? 1 : 0;

if ($in{'delete'}) {
	# delete the server
	&delete_server($in{'id'});
	&webmin_log("delete", "server", $serv->{'host'}, $serv); 
	}
else {
	# validate inputs
	$in{'host'} =~ /^[A-Za-z0-9_][A-Za-z0-9_\-\.]*$/ ||
		&check_ip6address($in{'host'}) || &error($text{'save_ehost'});
	$in{'type'} eq $serv->{'type'} ||
	    &indexof($in{'type'}, map { $_->[0] } &get_server_types()) >= 0 ||
		&error($text{'save_etype'});
	if ($in{'port_def'}) {
		$in{'mode'} == 0 || &error($text{'save_eport2'});
		}
	else {
		$in{'port'} =~ /^\d+$/ || &error($text{'save_eport'});
		}
	if ($in{'mode'} == 1) {
		&to_ipaddress($in{'host'}) || &to_ip6address($in{'host'}) ||
			&error($text{'save_ehost2'});
		$in{'wuser'} =~ /\S/ || &error($text{'save_euser'});

		# The stored password is not sent to the browser, so keep it
		# when the field is left empty, unless the destination changed
		if ($in{'wpass'} eq '' && $in{'id'} && $oldmode == 1 &&
		    $in{'host'} eq $serv->{'host'} &&
		    ($in{'port_def'} ? '' : $in{'port'}) eq $serv->{'port'}) {
			$in{'wpass'} = $serv->{'pass'};
			}
		$in{'wpass'} =~ /\S/ || &error($text{'save_epass'});
		}
	# Probe only automatic mode; leave explicit transport choices unchanged.
	if ($in{'fast'} == 2 && $in{'mode'} == 1) {
		# Test the submitted login through the normal RPC client.
		# Preserve saved fields, but resolve a changed hostname again.
		my $probe = { %$serv, host => $in{'host'},
			port => $in{'port'}, ip => undef,
			ssl => $in{'ssl'}, checkssl => $in{'checkssl'},
			fast => 1,
			user => $in{'wuser'}, pass => $in{'wpass'},
			sameuser => 0 };
		my $probe_error;
		{
		# Capture failures, then close any probe sessions.
		local $main::remote_error_handler = sub {
			$probe_error = $_[0];
			};
		&remote_rpc_call($probe, { action => 'ping' });
		&remote_finished();
		}
		# Keep the usual message for a rejected login.
		&error($text{'save_elogin'})
			if ($probe_error &&
			    $probe_error =~ /login to RPC server.*rejected/);
		# Stop on SSL or pin errors instead of saving regular RPC.
		&error(&html_escape($probe_error))
			if ($probe_error && ($in{'ssl'} ||
					     &server_ssl_fingerprints($probe)));
		# Failed unpinned HTTP probes still select regular RPC.
		$in{'fast'} = $probe_error ? 0 : 1;
		}
	elsif ($in{'fast'} == 2) {
		# Without a saved login, defer automatic detection until later.
		}

	# save the server
	my @groups = split(/\0/, $in{'group'});
	if ($in{'newgroup'}) {
		$in{'newgroup'} =~ /^\S+$/ || &error($text{'save_egroup2'});
		push(@groups, $in{'newgroup'});
		}
	$serv->{'host'} = $in{'host'};
	$serv->{'port'} = $in{'port_def'} ? undef : $in{'port'};
	$serv->{'type'} = $in{'type'};
	$serv->{'ssl'} = $in{'ssl'};
	$serv->{'checkssl'} = $in{'checkssl'};
	$serv->{'desc'} = $in{'desc_def'} ? undef : $in{'desc'};
	$serv->{'group'} = join("\t", @groups);
	$serv->{'fast'} = $in{'fast'} // 1;
	delete($serv->{'user'});
	delete($serv->{'pass'});
	delete($serv->{'autouser'});
	delete($serv->{'sameuser'});
	if ($in{'mode'} == 1) {
		$serv->{'user'} = $in{'wuser'};
		$serv->{'pass'} = $in{'wpass'};
		}
	elsif ($in{'mode'} == 2) {
		$serv->{'autouser'} = 1;
		}
	elsif ($in{'mode'} == 3) {
		$serv->{'user'} = 'same';
		$serv->{'sameuser'} = 1;
		}
	&save_server($serv);
	delete($serv->{'pass'});
	&webmin_log($in{'new'} ? 'create' : 'modify', 'server',
		    $serv->{'host'}, $serv);
	}
&redirect("");

