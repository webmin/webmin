#!/usr/local/bin/perl
# save_host.cgi
# Create, modify or delete an allowed host record

require './postgresql-lib.pl';
&ReadParse();
&lock_file($hba_conf_file);
$v = &get_postgresql_version();
@all = &get_hba_config($v);
$host = $all[$in{'idx'}] if (!$in{'new'});
&error_setup($text{'host_err'});

if ($in{'delete'}) {
	# delete one host
	&delete_hba($host, $v);
	}
else {
	# validate and parse inputs
	if ($in{'addr_mode'} == 0) {
		$host->{'address'} = '0.0.0.0' if (!$host->{'address'});
		$object = $host->{'netmask'} = '0.0.0.0';
		$host->{'type'} = $in{'ssl'} ? 'hostssl' : 'host';
		}
	elsif ($in{'addr_mode'} == 1) {
		&check_ipaddress($in{'host'}) ||
		  &check_ip6address($in{'host'}) ||
			&error($text{'host_ehost'});
		$object = $host->{'address'} = $in{'host'};
		$host->{'netmask'} = '255.255.255.255';
		$host->{'type'} = $in{'ssl'} ? 'hostssl' : 'host';
		}
	elsif ($in{'addr_mode'} == 2) {
		# Parse address / netmask
		&check_ipaddress($in{'network'}) ||
		   &check_ip6address($in{'network'}) ||
			&error($text{'host_enetwork'});
		&check_ipaddress($in{'netmask'}) ||
			&error($text{'host_enetmask'});
		$host->{'address'} = $in{'network'};
		$host->{'netmask'} = $in{'netmask'};
		delete($host->{'cidr'});
		$host->{'type'} = $in{'ssl'} ? 'hostssl' : 'host';
		$object = "$in{'network'}/$in{'netmask'}";
		}
	elsif ($in{'addr_mode'} == 4) {
		# Parse address / CIDR
		&check_ipaddress($in{'network2'}) ||
		    &check_ip6address($in{'network2'}) ||
			&error($text{'host_enetwork'});
		$in{'cidr'} =~ /^\d+$/ ||
			&error($text{'host_ecidr'});
		$host->{'address'} = $in{'network2'};
		$host->{'cidr'} = $in{'cidr'};
		delete($host->{'netmask'});
		$host->{'type'} = $in{'ssl'} ? 'hostssl' : 'host';
		$object = "$in{'network2'}/$in{'cidr'}";
		}
	else {
		$object = $host->{'type'} = 'local';
		}
	if ($in{'db'}) {
		$host->{'db'} = $in{'db'};
		}
	else {
		$in{'dbother'} || &error($text{'host_edb'});
		$host->{'db'} = join(",", split(/\s+/, $in{'dbother'}));
		}
	if ($v >= 7.3) {
		$in{'user_def'} || $in{'user'} || &error($text{'host_euser'});
		$host->{'user'} = $in{'user_def'} ? 'all' :
					join(",", split(/\s+/, $in{'user'}));
		}
	$host->{'auth'} = $in{'auth'};
	if ($in{'auth'} eq 'password' && $in{'passwordarg'}) {
		$in{'password'} =~ /^\S+$/ || &error($text{'host_epassword'});
		$host->{'arg'} = $in{'password'};
		}
	elsif ($in{'auth'} eq 'ident' && $in{'identarg'} == 1) {
		$in{'ident'} =~ /^\S+$/ || &error($text{'host_eident'});
		$host->{'arg'} = $in{'ident'};
		}
	elsif ($in{'auth'} eq 'ident' && $in{'identarg'} == 2) {
		$host->{'arg'} = 'sameuser';
		}
	elsif ($in{'auth'} eq 'peer' && $in{'peerarg'} == 1) {
		$in{'peer'} =~ /^\S+$/ || &error($text{'host_eident'});
		$host->{'arg'} = $in{'peer'};
		}
	elsif ($in{'auth'} eq 'peer' && $in{'peerarg'} == 2) {
		$host->{'arg'} = 'sameuser';
		}
	elsif ($in{'auth'} eq 'pam' && $in{'pamarg'}) {
		$in{'pam'} =~ /^\S+$/ || &error($text{'host_epam'});
		$host->{'arg'} = $in{'pam'};
		}
	else {
		$host->{'arg'} = undef;
		}

	if ($in{'new'}) {
		&create_hba($host, $v);
		}
	else {
		&modify_hba($host, $v);
		}
	}
&unlock_file($hba_conf_file);
&restart_postgresql();
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    'hba', $host->{'type'} eq 'local' ? 'local' :
		   $host->{'netmask'} eq '0.0.0.0' ? 'all' :
		   $host->{'netmask'} eq '255.255.255.255' ? $host->{'address'}:
		   "$host->{'address'}/$host->{'netmask'}", $host);
&redirect("list_hosts.cgi");

