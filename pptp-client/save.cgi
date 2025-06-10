#!/usr/local/bin/perl
# save.cgi
# Create, update or delete a PPTP tunnel

require './pptp-client-lib.pl';
&ReadParse();
@tunnels = &list_tunnels();
@secs = &list_secrets();
if (!$in{'new'}) {
	($tunnel) = grep { $_->{'name'} eq $in{'old'} } @tunnels;
	&parse_comments($tunnel);
	$name = &find("name", $tunnel->{'opts'});
	$remote = &find("remotename", $tunnel->{'opts'});
	$sec = &find_secret($name ? $name->{'value'} : &get_system_hostname(1),
			    $remote ? $remote->{'value'} : undef);
	&lock_file($tunnel->{'file'});
	}
else {
	$tunnel = { 'opts' => [ ] };
	}
&error_setup($text{'save_err'});
&lock_file($config{'pap_file'});

if ($in{'delete'}) {
	# Just delete this tunnel and it's secret (if not used by any other)
	unlink($tunnel->{'file'});
	}
else {
	# Validate inputs
	$in{'tunnel'} =~ /\S/ || &error($text{'save_ename'});
	&to_ipaddress($in{'server'}) || &error($text{'save_eserver'});
	$in{'login_def'} || $in{'login'} =~ /^\S+$/ ||
		&error($text{'save_elogin'});
	$in{'remote_def'} || $in{'remote'} =~ /^\S+$/ ||
		&error($text{'save_eremote'});
	$in{'file_def'} < 2 || -r $in{'file'} ||
		&error($text{'save_efile'});

	# Add default route changes
	if ($in{'deldef'}) {
		push(@routes, "delete default");
		}
	if ($in{'adddef'} == 1) {
		push(@routes, "add default dev TUNNEL_DEV");
		}
	elsif ($in{'adddef'} == 2) {
		&to_ipaddress($in{'def'}) || &error($text{'save_edef'});
		push(@routes, "add default gw ".$in{'def'});
		}

	# Parse and add extra route commands
	$in{'unknown'} =~ s/\r//g;
	push(@routes, grep { /\S/ } split(/\n/, $in{'unknown'}));

	# Parse and add static routes
	for($i=0; defined($t = $in{"type_$i"}); $i++) {
		next if (!$t);
		if ($t == 1) {
			&check_ipaddress($in{"net_$i"}) ||
				&error(&text('save_enet', $i+1));
			&check_ipaddress($in{"mask_$i"}) ||
				&error(&text('save_emask', $i+1));
			$in{"gw_def_$i"} || &check_ipaddress($in{"gw_$i"}) ||
				&error(&text('save_egw', $i+1));
			if ($in{"gw_def_$i"}) {
				push(@routes,
				    sprintf("add -net %s dev %s netmask %s",
					$in{"net_$i"}, 'TUNNEL_DEV',
					$in{"mask_$i"}));
				}
			else {
				push(@routes,
				    sprintf("add -net %s gw %s netmask %s",
					$in{"net_$i"}, $in{"gw_$i"},
					$in{"mask_$i"}));
				}
			}
		else {
			&check_ipaddress($in{"net_$i"}) ||
				&error(&text('save_ehost', $i+1));
			$in{"mask_$i"} && &error(&text('save_emask2', $i+1));
			$in{"gw_def_$i"} || &check_ipaddress($in{"gw_$i"}) ||
				&error(&text('save_egw2', $i+1));
			if ($in{"gw_def_$i"}) {
				push(@routes,
				    sprintf("add -host %s dev %s",
					$in{"net_$i"}, 'TUNNEL_DEV'));
				}
			else {
				push(@routes,
				    sprintf("add -host %s gw %s",
					$in{"net_$i"}, $in{"gw_$i"}));
				}
			}
		}


	mkdir($config{'peers_dir'}, 0755);
	if ($in{'new'}) {
		&check_clash();

		# Create file and set default options
		$tunnel->{'name'} = $in{'tunnel'};
		$tunnel->{'file'} = "$config{'peers_dir'}/$in{'tunnel'}";
		&lock_file($tunnel->{'file'});
		&save_ppp_option($tunnel->{'opts'}, $tunnel->{'file'}, undef,
				 { 'comment' => "PPTP Tunnel configuration for tunnel $in{'tunnel'}" });
		}
	else {
		# Check for a re-name
		if ($in{'tunnel'} ne $tunnel->{'name'}) {
			&check_clash();
			$tunnel->{'name'} = $in{'tunnel'};
			$nf = "$config{'peers_dir'}/$in{'tunnel'}";
			rename($tunnel->{'file'}, $nf) ||
				&error($text{'save_erename'});
			$tunnel->{'file'} = $nf;
			}
		}

	# Save server IP
	&save_ppp_option($tunnel->{'opts'}, $tunnel->{'file'},
			 $tunnel->{'server_c'},
			 { 'comment' => "Server IP: $in{'server'}" } );

	# Save all routes
	@or = @{$tunnel->{'routes_c'}};
	for($i=0; $i<@routes || $i<@or; $i++) {
		&save_ppp_option($tunnel->{'opts'}, $tunnel->{'file'},
				 $or[$i], $routes[$i] ?
					{ 'comment' => "Route: $routes[$i]" } : undef);
		}

	# Save PPP options
	&save_ppp_option($tunnel->{'opts'}, $tunnel->{'file'}, "name",
			 $in{'login_def'} ? undef :
			 { 'name' => 'name', 'value' => $in{'login'} } );
	&save_ppp_option($tunnel->{'opts'}, $tunnel->{'file'}, "remotename",
			 $in{'remote_def'} ? undef :
			 { 'name' => 'remotename','value' => $in{'remote'} } );
	&save_ppp_option($tunnel->{'opts'}, $tunnel->{'file'}, "file",
			 $in{'file_def'} == 0 ? undef :
			 $in{'file_def'} == 1 ? 
				{ 'name' => 'file',
				  'value' => $config{'pptp_options'} } :
				{ 'name' => 'file',
				  'value' => $in{'file'} });
	&parse_mppe_options($tunnel->{'opts'}, $tunnel->{'file'});

	# Update or add to the secrets file
	$newname = $in{'login_def'} ? &get_system_hostname(1) : $in{'login'};
	$newremote = $in{'remote_def'} ? "*" : $in{'remote'};
	if (!$sec) {
		# No old secret was found, so look for one matching the new
		# details
		$sec = &find_secret($newname, $newremote);
		}
	if ($sec) {
		# Just update the secret for our login name with the new login
		# and password. This can happen when re-naming, or if a secret
		# for the name already exists
		$sec->{'client'} = $newname;
		if ($sec->{'server'} ne '*' && $newremote ne '*') {
			$sec->{'server'} = $newremote;
			}
		$sec->{'secret'} = $in{'spass'};
		&change_secret($sec);
		}
	else {
		# Need to create a new secret
		$sec = { 'client' => $newname,
			 'secret' => $in{'spass'},
			 'server' => $newremote };
		&create_secret($sec);
		}

	&flush_file_lines();
	}
&unlock_file($tunnel->{'file'});
&unlock_file($config{'pap_file'});

&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "update",
	    "tunnel", $tunnel->{'name'});
&redirect("");

sub check_clash
{
-r "$config{'peers_dir'}/$in{'tunnel'}" && &error($text{'save_eclash'});
}

# find_secret(client, server)
# Returns the best matching secret with the given details
sub find_secret
{
local ($exact) = grep { $_->{'client'} eq $_[0] &&
			$_->{'server'} eq $_[1] } @secs;
return $exact if ($exact);
local ($client) = grep { $_->{'client'} eq $_[0] } @secs;
return $client;
}

