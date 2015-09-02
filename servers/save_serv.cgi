#!/usr/local/bin/perl
# save_serv.cgi
# Save or delete a server

use strict;
use warnings;
require './servers-lib.pl';
our (%in, %access, %text);
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

if ($in{'delete'}) {
	# delete the server
	&delete_server($in{'id'});
	&webmin_log("delete", "server", $serv->{'host'}, $serv); 
	}
else {
	# validate inputs
	$in{'host'} =~ /^\S+$/ || &error($text{'save_ehost'});
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
		$in{'wpass'} =~ /\S/ || &error($text{'save_epass'});
		}
	if ($in{'fast'} == 2 && $in{'mode'} == 1) {
		# Does the server have fastrpc.cgi ?
		my $con = &make_http_connection($in{'host'}, $in{'port'},
					   $in{'ssl'}, "GET", "/fastrpc.cgi");
		$in{'fast'} = 0;
		if (ref($con)) {
			&write_http_connection($con,
				        "Host: $serv->{'host'}\r\n");
			&write_http_connection($con,
					"User-agent: Webmin\r\n");
			my $auth = &encode_base64("$in{'wuser'}:$in{'wpass'}");
			$auth =~ s/\n//g;
			&write_http_connection($con,
					"Authorization: basic $auth\r\n");
			&write_http_connection($con, "\r\n");
			my $line = &read_http_connection($con);
			if ($line =~ /^HTTP\/1\..\s+401\s+/) {
				&error($text{'save_elogin'});
				}
			elsif ($line =~ /^HTTP\/1\..\s+200\s+/) {
				# It does .. tell the fastrpc.cgi process to die
				do {
					$line = &read_http_connection($con);
					$line =~ s/\r|\n//g;
					} while($line);
				$line = &read_http_connection($con);
				if ($line =~ /^1\s+(\S+)\s+(\S+)/) {
					my ($port, $sid, $error) = ($1, $2);
					&open_socket($in{'host'}, $port,
						     $sid, \$error);
					if (!$error) {
						close($sid);
						$in{'fast'} = 1;
						}
					}
				}
			&close_http_connection($con);
			}
		}
	elsif ($in{'fast'} == 2) {
		# No login provided, so we cannot say for now ..
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
	$serv->{'fast'} = $in{'fast'};
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

