#!/usr/local/bin/perl
# save_servers.cgi
# Update all the server directives

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'servers_ecannot'});
&error_setup($text{'servers_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
$conf = &get_config();
@old = &find("server", $conf);
for($i=0; defined($ip = $in{"ip_$i"}); $i++) {
	next if (!$ip);
	&check_ipaddress($ip) || &check_ip6address($ip) ||
		&error(&text('servers_eip', $ip));
	$in{"trans_$i"} =~ /^\d*$/ ||
		&error(&text('servers_etrans', $in{"trans_$i"}));
	local $s = { 'name' => 'server',
		     'type' => 1 };
	$s->{'members'} = $old[$i] ? $old[$i]->{'members'} : [ ];
	$s->{'values'} = [ $ip ];
	&save_directive($s, 'bogus',
		$in{"bogus_$i"} ? [ { 'name' => 'bogus',
				      'values' => [ 'yes' ] } ] : [ ], 1, 1);
	&save_directive($s, 'transfer-format',
		$in{"format_$i"} ? [ { 'name' => 'transfer-format',
				       'values' => [ $in{"format_$i"} ] } ]
				 : [ ], 1, 1);
	&save_directive($s, 'transfers',
		$in{"trans_$i"} ne '' ? [ { 'name' => 'transfers',
				            'values' => [ $in{"trans_$i"} ] } ]
				      : [ ], 1, 1);

	@keys = split(/\0/, $in{"keys_$i"});
	if (@keys) {
		local @mems = map { { 'name' => $_ } } @keys;
		&save_directive($s, 'keys',
			[ { 'name' => 'keys',
			    'type' => 1,
			    'members' => \@mems } ], 1, 1);
		}
	else {
		&save_directive($s, 'keys', [ ], 1, 1);
		}
		
	push(@servers, $s);
	}
&save_directive(&get_config_parent(), 'server', \@servers, 0);
&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("servers", undef, undef, \%in);
&redirect("");

