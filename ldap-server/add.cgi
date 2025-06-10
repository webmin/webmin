#!/usr/local/bin/perl
# Create a whole new object

require './ldap-server-lib.pl';
&error_setup($text{'oadd_err'});
&ReadParse();
$ldap = &connect_ldap_db();
ref($ldap) || &error($ldap);

# Validate inputs
$in{'dn1'} =~ /^\S+$/ || &error($text{'oadd_edn1'});
$in{'dn2'} =~ /\S/ || &error($text{'oadd_edn2'});
@classes = split(/\r?\n/, $in{'classes'});
@classes || &error($text{'oadd_eclasses'});
foreach $c (@classes) {
	$c =~ /^\S+$/ || &error(&text('oadd_eclass', $c));
	}
push(@attrs, "objectClass", \@classes);
for($i=0; defined($in{"name_$i"}); $i++) {
	next if ($in{"name_$i"} eq "");
	$in{"name_$i"} =~ /^\S+$/ ||  &error(&text('oadd_ename', $i+1));
	push(@attrs, $in{"name_$i"}, [ split(/\r?\n/, $in{"value_$i"}) ]);
	}
$dn = $in{'dn1'}."=".$in{'dn2'};
$dn .= ", $in{'base'}" if ($in{'base'});

# Check for a clash
$rv = $ldap->search(base => $dn,
		    filter => '(objectClass=*)',
		    scope => 'base');
if ($rv && !$rv->code) {
	($clash) = $rv->all_entries;
	$clash && &error(&text('oadd_eclash', "<tt>$dn</tt>"));
	}

# Create the object
$rv = $ldap->add($dn, attr => \@attrs);
if (!$rv || $rv->code) {
	&error(&text('oadd_eadd', "<tt>$dn</tt>",
				  &ldap_error($rv)));
	}

&webmin_log('create', 'dn', $dn);
&redirect("edit_browser.cgi?base=".&urlize($dn));

