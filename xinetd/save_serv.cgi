#!/usr/local/bin/perl
# save_serv.cgi
# Create, modify or delete an internet service

require './xinetd-lib.pl';
&ReadParse();
@conf = &get_xinetd_config();
if ($in{'new'}) {
	$xinet = { 'name' => 'service',
		   'members' => [ ] };
	}
else {
	$xinet = $conf[$in{'idx'}];
	($defs) = grep { $_->{'name'} eq 'defaults' } @conf;
	foreach $m (@{$defs->{'members'}}) {
		$ddisable{$m->{'value'}} = $m if ($m->{'name'} eq 'disabled');
		}
	$oldid = $xinet->{'quick'}->{'id'}->[0] || $xinet->{'value'};
	}

&lock_file($config{'xinetd_conf'});
if ($in{'delete'}) {
	# Delete a service
	&delete_xinet($xinet);
	}
else {
	# Validate inputs
	&error_setup($text{'serv_err'});
	$in{'id'} =~ /^\S+$/ || &error($text{'serv_eid'});
	$in{'bind_def'} || &check_ipaddress($in{'bind'}) ||
	    &check_ip6address($in{'bind'}) ||
		&error($text{'serv_ebind'});
	foreach $p (&list_protocols()) {
		@ps = getservbyname($in{'id'}, $p);
		last if (@ps);
		}
	if ($in{'port_def'}) {
		# make sure the service actually exists
		if ($in{'proto'}) {
			@s = getservbyname($in{'id'}, $in{'proto'});
			}
		else {
			@s = @ps;
			}
		@s || &error(&text('serv_estd', $in{'name'}));
		}
	else {
		$in{'port'} =~ /^\d+$/ || &error($text{'serv_eport'});
		$in{'proto'} || @ps || &error($text{'serv_eproto'});
		}
	$in{'inst_def'} || $in{'inst'} =~ /^\d+$/ ||
		&error($text{'serv_einst'});
	$in{'user'} || $in{'prog'} == 0 || &error($text{'serv_euser'});
	$in{'group_def'} || $in{'group'} || &error($text{'serv_egroup'});
	$in{'nice_def'} || $in{'nice'} =~ /^\d+$/ ||
		&error($text{'serv_enice'});
	if (!$in{'cps_def'}) {
		$in{'cps'} =~ /^\d+$/ || &error($text{'serv_ecps0'});
		$in{'cps1'} =~ /^\d+$/ || &error($text{'serv_ecps1'});
		}
	if (!$in{'times_def'}) {
		@times = split(/\s+/, $in{'times'});
		map { &error($text{'serv_etimes'}) if (!/^\d+:\d+\-\d+:\d+$/) }
		    @times;
		}

	# Create service structure
	$xinet->{'values'} = [ $in{'id'} ];
	&set_member_value($xinet, 'disable', $in{'disable'} ? 'yes' : undef);
	&set_member_value($xinet, 'port',
			  $in{'port_def'} ? undef : $in{'port'});
	&set_member_value($xinet, 'bind',
			  $in{'bind_def'} ? undef : $in{'bind'});
	&set_member_value($xinet, 'socket_type', $in{'sock'});
	&set_member_value($xinet, 'protocol', $in{'proto'} ? $in{'proto'}
							   : undef);

	&set_member_value($xinet, 'user', $in{'user'}) if ($in{'user'});
	&set_member_value($xinet, 'group',
			  $in{'group_def'} ? undef : $in{'group'});
	@type = @{$q->{'type'}};
	@flags = @{$q->{'flags'}};
	if ($in{'prog'} == 0) {
		@type = &unique(@type, 'INTERNAL');
		&set_member_value($xinet, 'server');
		&set_member_value($xinet, 'server_args');
		&set_member_value($xinet, 'redirect');
		}
	elsif ($in{'prog'} == 1) {
		@type = grep { $_ ne 'INTERNAL' } @type;
		@s = split(/\s+/, $in{'server'});
		$in{'disable'} || @s && -x $s[0] ||
			&error($text{'serv_eserver'});
		&set_member_value($xinet, 'server', shift(@s));
		&set_member_value($xinet, 'server_args', @s);
		&set_member_value($xinet, 'redirect');
		}
	else {
		&to_ipaddress($in{'rhost'}) ||
			&error($text{'serv_erhost'});
		$in{'rport'} =~ /^\d+$/ || &error($text{'serv_erport'});
		@type = grep { $_ ne 'INTERNAL' } @type;
		&set_member_value($xinet, 'server');
		&set_member_value($xinet, 'server_args');
		&set_member_value($xinet, 'redirect',
				  $in{'rhost'}, $in{'rport'});
		}
	if ($in{'port_def'} || (!$in{'port_def'} && !$in{'proto'} && @ps)) {
		@type = grep { $_ ne 'UNLISTED' } @type;
		}
	else {
		@type = &unique(@type, 'UNLISTED');
		}
	&set_member_value($xinet, 'type', @type);
	&set_member_value($xinet, 'wait', $in{'wait'} ? 'yes' : 'no');
	&set_member_value($xinet, 'instances',
			  $in{'inst_def'} ? undef : $in{'inst'});
	&set_member_value($xinet, 'nice',
			  $in{'nice_def'} ? undef : $in{'nice'});
	&set_member_value($xinet, 'cps',
			  $in{'cps_def'} ? ( ) : ( $in{'cps'},$in{'cps1'} ) );
	&set_member_value($xinet, 'only_from', $in{'from_def'} ? undef :
			  $in{'from'} ? split(/\s+/, $in{'from'}) : ("") );
	&set_member_value($xinet, 'no_access', $in{'access_def'} ? undef :
			  $in{'access'} ? split(/\s+/, $in{'access'}) : ("") );
	&set_member_value($xinet, 'access_times', $in{'times_def'} ? undef
								   : @times);

	if ($in{'new'}) {
		foreach $xi (@conf) {
			if ($xi->{'name'} eq 'service' &&
			    $xi->{'value'} eq $in{'id'}) {
				# A service with the same name exists!
				&set_member_value(
					$xinet, 'id', "$in{'id'}-$in{'sock'}");
				}
			}
		if (-d $config{'add_dir'}) {
			&lock_file($newfile);
			$newfile = "$config{'add_dir'}/$in{'id'}";
			&create_xinet($xinet, $newfile);
			&unlock_file($newfile);
			}
		else {
			&create_xinet($xinet);
			}
		}
	else {
		&modify_xinet($xinet);
		if ($ddisable{$oldid}) {
			# Take out old global disabled
			&delete_xinet($ddisable{$oldid});
			}
		}
	}
&unlock_file($config{'xinetd_conf'});
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'serv', $xinet->{'values'}->[0], $xinet->{'quick'});
&redirect("");

