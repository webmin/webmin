#!/usr/local/bin/perl
# save_host.cgi
# Update, create or delete a host

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
&lock_all_files();
($par, $host, $indent, $npar, $nindent) = get_branch('hst', $in{'new'});

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if ($in{'delete'}) {
	&error("$text{'eacl_np'} $text{'eacl_pdh'}")
		if !&can('rw', \%access, $host, 1);
	}
elsif ($in{'options'}) {
	&error("$text{'eacl_np'} $text{'eacl_psh'}")
		if !&can('r', \%access, $host);
	}
elsif ($in{'new'}) {
	&error("$text{'eacl_np'} $text{'eacl_pih'}")
		unless &can('c', \%access, $host) && 
				&can('rw', \%access, $par) &&
				(!$npar || &can('rw', \%access, $npar));
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_puh'}")
		unless &can('rw', \%access, $host) &&
			(!$npar || &can('rw', \%access, $npar));
	$oldname = $host->{'values'}->[0];
	}

# save
if ($in{'delete'}) {
	# Delete this host
	&error_setup($text{'shost_faildel'});
	&save_directive($par, [ $host ], [ ], 0);
	&drop_dhcpd_acl('hst', \%access, $host->{'values'}->[0]);
	}
elsif ($in{'options'}) {
	# Redirect to client options
	&redirect("edit_options.cgi?sidx=$in{'sidx'}&uidx=$in{'uidx'}&gidx=$in{'gidx'}&idx=$in{'idx'}");
	exit;
	}
else {
	&error_setup($text{'shost_failsave'});

	# Validate and save inputs
	$in{'name'} =~ /^[a-z0-9\.\-\_]+$/i ||
		&error("'$in{'name'}' $text{'shost_invalidhn'}");
	$host->{'comment'} = $in{'desc'};

	# Check for a hostname clash
	if (($in{'new'} || $in{'name'} ne $host->{'values'}->[0]) &&
	    $access{'uniq_hst'}) {
		foreach $h (&get_my_shared_network_hosts($npar)) {
                        &error("$text{'eacl_np'} $text{'eacl_uniq'}")
                                if (lc($h->{'values'}->[0]) eq lc($in{'name'}));
                        }
		}
	$host->{'values'} = [ $in{'name'} ];

	if ($in{'hardware'}) {
		# Check for hardware clash
		$oldhard = $in{'new'} ? undef
				      : &find("hardware", $host->{'members'});
		if ((!$oldhard || $in{'hardware'} ne $oldhard->{'values'}->[1])
		    && $access{'uniq_hst'}) {
			foreach $h (&get_my_shared_network_hosts($npar)) {
				$chard = &find("hardware", $h->{'members'});
				&error("$text{'eacl_np'} $text{'eacl_uniqh'}")
					if ($chard && lc($chard->{'values'}->[1]) eq lc($in{'hardware'}));
				}
			}

		# Convert from Windows / Cisco formats
		$in{'hardware'} =~ s/-/:/g;
		if ($in{'hardware'} =~ /^([0-9a-f]{2})([0-9a-f]{2}).([0-9a-f]{2})([0-9a-f]{2}).([0-9a-f]{2})([0-9a-f]{2}).([0-9a-f]{2})([0-9a-f]{2})$/i) {
			$in{'hardware'} = "$1:$2:$3:$4:$5:$6";
			}
		# Handle an Ethernet address with no formatting at all
		if ($in{'hardware'} =~ /^([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i) {
			$in{'hardware'} = "$1:$2:$3:$4:$5:$6";
			}
		$in{'hardware'} =~ /^([0-9a-f]{1,2}:)*[0-9a-f]{1,2}$/i ||
			&error(&text('shost_invalidhwa', $in{'hardware'},
				     $in{'hardware_type'}) );
		@hard = ( { 'name' => 'hardware',
			    'values' => [ $in{'hardware_type'},
					  $in{'hardware'} ] } );
		}
	&save_directive($host, 'hardware', \@hard);

	if ($in{'fixed-address'}) {
		# Check for IP clash
		$oldfixed = $in{'new'} ? undef
			      : &find("fixed-address", $host->{'members'});
		if ((!$oldfixed ||
		    $in{'fixed-address'} ne $oldfixed->{'values'}->[0])
		    && $access{'uniq_hst'}) {
			foreach $h (&get_my_shared_network_hosts($npar)) {
				$cfixed = &find("fixed-address",
						$h->{'members'});
				&error("$text{'eacl_np'} $text{'eacl_uniqi'}")
					if ($cfixed && lc($cfixed->{'values'}->[0]) eq lc($in{'fixed-address'}));
				}
			}

		# Save IP address
		if ($in{'fixed-address'} !~ /^[\w\s\.\-,]+$/ ||
		    $in{'fixed-address'} =~ /(^|[\s,])[-_]/ ||
		    $in{'fixed-address'} =~ /\.([\s,\.]|$)/ ||
		    $in{'fixed-address'} =~ /(^|[\s,])\d+\.[\d\.]*[a-z_]/i) {
			&error(&text('shost_invalidaddr', $in{'fixed-address'}));	
			}
		@fixedip = split(/[,\s]+/, $in{'fixed-address'});
		@fixed = ( { 'name' => 'fixed-address',
			     'values' => [ join(" , ", @fixedip) ] } );
		}
	&save_directive($host, 'fixed-address', \@fixed);

	&parse_params($host);

	@partypes = ( "", "shared-network", "subnet", "group" );
	if (!$npar || $in{'assign'} > 0 && $npar->{'name'} ne $partypes[$in{'assign'}]) {
		if ($in{'jsquirk'}) {
			&error($text{'shost_invassign'});
			}
		else {
			&redirect("edit_host.cgi?assign=".$in{'assign'}.
				"&idx=".$in{'idx'}."&gidx=".$in{'gidx'}.
				"&uidx=".$in{'uidx'}."&sidx=".$in{'sidx'});
			exit;
			}
		}
	if ($in{'new'}) {
		# save acl for new host
		&save_dhcpd_acl('rw', 'hst', \%access, $in{'name'});
		# Add to the end of the parent structure
		&save_directive($npar, [ ], [ $host ], $nindent);
		}
	elsif ($par eq $npar) {
		# Update host
		&save_directive($par, [ $host ], [ $host ], $indent);
		if ($oldname ne $in{'name'}) {
			&drop_dhcpd_acl('hst', \%access, $oldname);
			&save_dhcpd_acl('rw', 'hst', \%access, $in{'name'});
			}
		}
	else {
		# Move this host
		&save_directive($par, [ $host ], [ ], 0);
		&save_directive($npar, [ ], [ $host ], $nindent);
		}
	}
&flush_file_lines();
&unlock_all_files();
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'host', $host->{'values'}->[0], \%in);
if ($in{'ret'} eq "group") {
	$retparms = "sidx=$in{'sidx'}&uidx=$in{'uidx'}&idx=$in{'gidx'}";
	}
elsif ($in{'ret'} eq "subnet") {
	$retparms = "sidx=$in{'sidx'}&idx=$in{'uidx'}";
	}
elsif ($in{'ret'} eq "shared") {
	$retparms = "idx=$in{'sidx'}";
	}

&redirect($in{'ret'} ? "edit_$in{'ret'}.cgi?$retparms" : "");
