#!/usr/local/bin/perl
# Create, update or delete one access control rule

require './ldap-server-lib.pl';
&error_setup($text{'eacl_err'});
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'acl'} || &error($text{'acl_ecannot'});
&ReadParse();

# Get the current rule
&lock_file($config{'config_file'});
$conf = &get_config();
@access = &find("access", $conf);
if (!$in{'new'}) {
	$acl = $access[$in{'idx'}];
	$p = &parse_ldap_access($acl);
	}

if ($in{'delete'}) {
	# Just take out of access list
	@access = grep { $_ me $acl } @access;
	}
else {
	# Validate and store inputs, starting with object
	if ($in{'what'} == 0) {
		$p->{'what'} = '*';
		}
	else {
		$in{'dn'} =~ /^\S+=\S+$/ || &error($text{'eacl_edn'});
		$p->{'what'} = 'dn='.($in{'style'} ? '.'.$in{'style'} : '').
			       $in{'dn'};
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
	# XXX

	# Add to access directive list
	if ($in{'new'}) {
		$acl = { 'name' => 'access',
			 'values' => [ ] };
		push(@access);
		}
	&store_ldap_access($acl, $p);
	}

# Write out access directives
&save_directive($conf, "access", @access);
&flush_file_lines($config{'config_file'});
&unlock_file($config{'config_file'});

# Log and return
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "access", $p->{'who'});
&redirect("edit_acl.cgi");

