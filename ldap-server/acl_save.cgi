#!/usr/local/bin/perl
# Create, update or delete one access control rule

require './ldap-server-lib.pl';
&error_setup($text{'eacl_err'});
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'acl'} || &error($text{'acl_ecannot'});
&ReadParse();

# Get the current rule
&lock_slapd_files();
if (&get_config_type() == 1) {
	$conf = &get_config();
	@access = &find("access", $conf);
	$hasorder = 0;
	}
else {
	$defdb = &get_default_db();
	$conf = &get_ldif_config();
	@access = &find_ldif("olcAccess", $conf, $defdb);
	$hasorder = 1;
	}

# Get the ACL object
if (!$in{'new'}) {
	$acl = $access[$in{'idx'}];
	$p = &parse_ldap_access($acl);
	}
else {
	$p = { };
	}

if ($in{'delete'}) {
	# Just take out of access list
	@access = grep { $_ ne $acl } @access;
	}
else {
	# Validate and store inputs, starting with object
	if ($in{'what'} == 1) {
		$p->{'what'} = '*';
		}
	elsif ($in{'what'} == 2) {
		$p->{'what'} =
			'dn'.($in{'what_style'} ? '.'.$in{'what_style'} : '').
			'=""';
		}
	else {
		$in{'what_dn'} =~ /^\S+=\S.*$/ || &error($text{'eacl_edn'});
		$p->{'what'} =
			'dn'.($in{'what_style'} ? '.'.$in{'what_style'} : '').
			'='.$in{'what_dn'};
		}

	# Object filter and attribute list
	delete($p->{'filter'});
	if ($in{'filter_on'}) {
		$in{'filter'} =~ /^\S+$/ || &error($text{'eacl_efilter'});
		$p->{'filter'} = $in{'filter'};
		}
	delete($p->{'attrs'});
	if ($in{'attrs_on'}) {
		$in{'attrs'} =~ /^\S+$/ || &error($text{'eacl_eattrs'});
		$p->{'attrs'} = $in{'attrs'};
		}

	# Each granted user
	@by = ( );
	for($i=0; defined($in{"wmode_$i"}); $i++) {
		next if ($in{"wmode_$i"} eq "");
		local $by = { };

		# Who are we granting
		if ($in{"wmode_$i"} eq "other") {
			# Other DN
			$in{"who_$i"} =~ /^\S+=\S.*$/ ||
				&error(&text('eacl_ewho', $i+1));
			$by->{'who'} = $in{"who_$i"};
			}
		else {
			# Just selected
			$by->{'who'} = $in{"wmode_$i"};
			}

		# Access level
		$in{"access_$i"} =~ /^\S+$/ ||
			&error(&text('eacl_eaccess', $i+1));
		$by->{'access'} = $in{"access_$i"};

		# Additional attributes
		$by->{'control'} = [ &split_quoted_string($in{"control_$i"}) ];
		push(@by, $by);
		}
	$p->{'by'} = \@by;

	# Set order to end of list, if we are using orders
	if ($hasorder && $in{'new'}) {
		$maxorder = -1;
		foreach $oa (@access) {
			$op = &parse_ldap_access($oa);
			if ($op->{'order'} > $maxorder) {
				$maxorder = $op->{'order'};
				}
			}
		$p->{'order'} = $maxorder + 1;
		}

	# Add to access directive list
	if ($in{'new'}) {
		$acl = { 'name' => 'access',
			 'values' => [ ] };
		push(@access, $acl);
		}
	&store_ldap_access($acl, $p);
	}

# Write out access directives
if (&get_config_type() == 1) {
	&save_directive($conf, "access", @access);
	}
else {
	&save_ldif_directive($conf, "olcAccess", $defdb, @access);
	}
&flush_file_lines();
&unlock_slapd_files();

# Log and return
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "access", $p->{'what'});
&redirect("edit_acl.cgi");

