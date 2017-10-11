#!/usr/local/bin/perl
# save_options.cgi
# Save client options for some subnet, shared net, group, host or global

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
&lock_all_files();
$client = &get_parent_config();
push(@parents, $client);
foreach $i ($in{'sidx'}, $in{'uidx'}, $in{'gidx'}, $in{'idx'}) {
	if ($i ne '') {
		$client = $client->{'members'}->[$i];
		push(@parents, $client);
		$indent++;
		}
	}

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if ($client->{'name'} eq 'subnet') {
	&error("$text{'eacl_np'} $text{'eacl_pus'}")
		if !&can('rw', \%access, $client);
	}
elsif ($client->{'name'} eq 'shared-network') {
	&error("$text{'eacl_np'} $text{'eacl_pun'}")
		if !&can('rw', \%access, $client);
	}
elsif ($client->{'name'} eq 'host') {
	&error("$text{'eacl_np'} $text{'eacl_puh'}")
		if !&can('rw', \%access, $client);
	}
elsif ($client->{'name'} eq 'group') {
	&error("$text{'eacl_np'} $text{'eacl_pug'}")
		if !&can('rw', \%access, $client);
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_pglob'}")
		if !$access{'global'};
	}

# save
&error_setup($text{'sopt_failsave'});

&save_option("host-name", 3, $client, $indent);
&save_option("routers", 2, $client, $indent);
&save_option("subnet-mask", 0, $client, $indent);
&save_option("broadcast-address", 0, $client, $indent);
&save_option("domain-name", 3, $client, $indent);
&save_option("domain-name-servers", 2, $client, $indent);
&save_option("domain-search", 6, $client, $indent);
&save_option("time-servers", 2, $client, $indent);
&save_option("log-servers", 2, $client, $indent);
&save_option("swap-server", 2, $client, $indent);
&save_option("root-path", 3, $client, $indent);
&save_option("nis-domain", 3, $client, $indent);
&save_option("nis-servers", 2, $client, $indent);
&save_option("font-servers", 2, $client, $indent);
&save_option("x-display-manager", 2, $client, $indent);
&save_option("static-routes", 5, $client, $indent);
&save_option("ntp-servers", 2, $client, $indent);
&save_option("netbios-name-servers", 2, $client, $indent);
&save_option("netbios-scope", 3, $client, $indent);
&save_option("netbios-node-type", 1, $client, $indent);
&save_option("time-offset", 1, $client, $indent);
&save_option("dhcp-server-identifier", 2, $client, $indent);
&save_option("slp-directory-agent", 2, $client, $indent, 1);
&save_option("slp-service-scope", 3, $client, $indent, 1);
if ($in{'level'} eq "global") {
	# save params as well
	&save_choice("use-host-decl-names", $client, 0);
	&parse_params($client, 0);
	}
elsif ($in{'level'} eq "host") {
	$ret="edit_host.cgi?sidx=$in{'sidx'}&uidx=$in{'uidx'}&gidx=$in{'gidx'}&idx=$in{'idx'}";
	}
elsif ($in{'level'} eq "group") {
	$ret="edit_group.cgi?sidx=$in{'sidx'}&uidx=$in{'uidx'}&idx=$in{'idx'}";
	}
elsif ($in{'level'} eq "subnet") {
	$ret="edit_subnet.cgi?sidx=$in{'sidx'}&idx=$in{'idx'}";
	}
elsif ($in{'level'} eq "shared-network") {
	$ret="edit_shared.cgi?idx=$in{'idx'}";
	}

if ($config{'dhcpd_version'} >= 3) {
	# Save option definitions, new DHCPd
	@defs = grep { $_->{'name'} eq 'option' &&
			 $_->{'values'}->[1] eq 'code' &&
			 $_->{'values'}->[3] eq '=' }
		       @{$client->{'members'}};
	%optdef = map { $_->{'values'}->[0], $_ } @defs;
	for($i=0; defined($in{"dname_$i"}); $i++) {
		next if (!$in{"dname_$i"} || !$in{"dnum_$i"} ||
			 !$in{"dtype_$i"});
		$in{"dname_$i"} =~ /^[a-z0-9\.\-\_]+$/i ||
			&error(&text('sopt_edname', $in{"dname_$i"}));
		$in{"dnum_$i"} =~ /^\d+$/ ||
			&error(&text('sopt_ednum', $in{"dnum_$i"}));
		if ($in{"dtype_$i"} =~ /^[a-z0-9\s\.\-\_]+$/i) {
			@dtypes = ( $in{"dtype_$i"} );
			}
		elsif ($in{"dtype_$i"} =~ /^\{.*\}$/) {
			@dtypes = split(/\s+/, $in{"dtype_$i"});
			}
		else {
			&error(&text('sopt_edtype', $in{"dtype_$i"}));
			}
		push(@newdefs, { 'name' => 'option',
				 'values' => [ $in{"dname_$i"}, "code",
					       $in{"dnum_$i"}, "=",
					       @dtypes,
					     ] } );
		}
	&save_directive($client, \@defs, \@newdefs, $indent, 1);

	# Find option definitions at higher levels
	foreach $p (@parents) {
		@popts = &find("option", $p->{'members'});
		@pdefs = grep { $_->{'values'}->[1] eq 'code' &&
			        $_->{'values'}->[3] eq '=' } @popts;
		foreach $o (@pdefs) {
			$optdef{$o->{'values'}->[0]} = $o
				if ($o->{'values'}->[0]);
			}
		}

	# Find the last definition
	$maxdef = undef;
	foreach $d (@newdefs) {
		$maxdef = $d if (!$maxdef || $d->{'line'} > $maxdef->{'line'});
		}

	# Save custom options
	@custom = grep { $_->{'name'} eq 'option' &&
			 $optdef{$_->{'values'}->[0]} &&
			 $_->{'values'}->[1] ne 'code' }
		       @{$client->{'members'}};
	for($i=0; defined($in{"cname_$i"}); $i++) {
		next if ($in{"cname_$i"} eq "");
		local $o = $optdef{$in{"cname_$i"}};
		local $cv = $in{"cval_$i"};
		$cv =~ /\S/ || &error(&text('sopt_ecval', $in{"cname_$i"}));
		if ($o && $o->{'values'}->[4] eq 'ip-address') {
			&check_ipaddress($cv) ||
			  &check_ip6address($cv) ||
			    &error(&text('sopt_ecip', $in{"cname_$i"}));
			}
		if ($o && $o->{'values'}->[4] =~ /^array\s+of\s+(\S+)/) {
			local $atype = $1;
			}
		elsif ($o && $o->{'values'}->[4] eq 'string' ||
		       $o && $o->{'values'}->[4] eq 'text' ||
		       $cv !~ /^([0-9a-fA-F]{1,2}:)*[0-9a-fA-F]{1,2}$/ &&
		       !&check_ipaddress($cv)) {
			# Quote if type is a string, or unknown and not an IP
			$cv = "\"$cv\"";
			}
		push(@newcustom, { 'name' => 'option',
				   'values' => [ $in{"cname_$i"}, $cv ] } );
		}
	&save_directive($client, \@custom, \@newcustom, $indent,
			$maxdef ? 0 : 1, $maxdef);
	}
else {
	# Save custom options, old DHCPd
	@custom = grep { $_->{'name'} eq 'option' &&
			 $_->{'values'}->[0] =~ /^option-(\S+)$/ &&
			 $_->{'values'}->[1] ne 'code' }
		       @{$client->{'members'}};
	for($i=0; defined($in{"cnum_$i"}); $i++) {
		next if (!$in{"cnum_$i"} || !$in{"cval_$i"});
		$in{"cnum_$i"} =~ /^\d+$/ ||
		   ($config{'dhcpd_version'} >= 3 &&
		    $in{"cnum_$i"} =~ /^\S+$/) ||
			&error(&text('sopt_ednum', $in{"cnum_$i"}));
		local $cv = $in{"cval_$i"};
		$cv = "\"$cv\""
			if ($cv !~ /^([0-9a-fA-F]{1,2}:)*[0-9a-fA-F]{1,2}$/ &&
			    !&check_ipaddress($cv));
		push(@newcustom, { 'name' => 'option',
				   'values' => [ 'option-'.$in{"cnum_$i"},
						 $cv ] } );
		}
	&save_directive($client, \@custom, \@newcustom, $indent, 1);
	}

&flush_file_lines();
&unlock_all_files();
if ($client->{'name'} eq 'subnet') {
	&webmin_log("options", 'subnet',
		    "$client->{'values'}->[0]/$client->{'values'}->[2]", \%in);
	}
elsif ($client->{'name'} eq 'shared-network') {
	&webmin_log("options", 'subnet', $client->{'values'}->[0], \%in);
	}
elsif ($client->{'name'} eq 'host') {
	&webmin_log("options", 'host', $client->{'values'}->[0], \%in);
	}
elsif ($client->{'name'} eq 'group') {
	@count = &find("host", $client->{'members'});
	&webmin_log("options", 'group',
		    join(",", map { $_->{'values'}->[0] } @count), \%in);
	}
&redirect($ret);

# save_option(name, type, &config, indent, [has-boolean])
sub save_option
{
local($v);
local $m = $_[2]->{'members'};
for($i=0; $i<@$m; $i++) {
	if ($m->[$i]->{'name'} eq 'option' &&
	    $m->[$i]->{'values'}->[0] eq $_[0]) {
		$v = $m->[$i];
		last;
		}
	}
if ($in{"$_[0]_def"}) {
	&save_directive($_[2], [ $v ], [ ], 0, 1) if ($v);
	}
else {
	local $nv = $in{$_[0]};
	local @nv = split(/\s+/, $nv);
	if ($_[1] == 0) {
		&to_ipaddress($nv) ||
			&error("$_[0] '$nv' $text{'sopt_invalidip'}");
		}
	elsif ($_[1] == 1) {
		$nv =~ /^-?\d+$/ || &error("'$nv' $text{'sopt_invalidint'}");
		}
	elsif ($_[1] == 2) {
		foreach my $ip (@nv) {
			&to_ipaddress($ip) ||
				&error("'$ip' $text{'sopt_invalidip'}");
			}
		$nv = join(", ", @nv);
		}
	elsif ($_[1] == 3) {
		$nv = "\"$nv\"";
		}
	elsif ($_[1] == 5) {
		local($ipp, @nnv);
		foreach $ipp (@nv) {
			$ipp =~ /^(\S+)\s*,\s*(\S+)$/ ||
				&error("'$ipp' $text{'sopt_invalidipp'}");
			&check_ipaddress($1) ||
				&error("'$1' $text{'sopt_invalidip'}");
			&check_ipaddress($2) ||
				&error("'$2' $text{'sopt_invalidip'}");
			push(@nnv, "$1 $2");
			}
		$nv = join(", ", @nnv);
		}
	elsif ($_[1] == 6) {
		$nv = join(", ", map { "\"$_\"" } @nv);
		}
	local @bool = !$_[4] ? ( ) :
		      $in{$_[0]."_bool"} ? ( "true" ) : ( "false" );
	local $dir = { 'name' => 'option',
		       'values' => [ $_[0], @bool, $nv ] };
	&save_directive($_[2], $v ? [ $v ] : [ ], [ $dir ], $_[3], 1);
	}
}

