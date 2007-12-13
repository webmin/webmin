#!/usr/local/bin/perl
# Change the DN of an LDAP object

require './ldap-server-lib.pl';
&error_setup($text{'rename_err'});
$access{'browser'} || &error($text{'browser_ecannot'});
&ReadParse();
$ldap = &connect_ldap_db();
ref($ldap) || &error($ldap);

# Get the object
$rv = $ldap->search(base => $in{'old'},
		     filter => '(objectClass=*)',
		     scope => 'base');
if (!$rv || $rv->code) {
	&error(&ldap_error($rv));
	}
($bo) = $rv->all_entries;
$bo || &error(&text('rename_eget', "<tt>$in{'old'}</tt>"));

# Work out the new DN parts
$in{'rename'} =~ /=/ || &error($text{'rename_enew'});
($newprefix, $newrest) = split(/,/, $in{'rename'}, 2);

# Do the rename
$rv = $ldap->moddn($bo->dn(),
		   newrdn => $newprefix,
		   newsuperior => $newrest);
if (!$rv || $rv->code) {
	&error(&text('rename_erename', "<tt>".$bo->dn()."</tt>",
				       "<tt>$in{'rename'}</tt>",
				       &ldap_error($rv)));
	}

# Return to object
&webmin_log('rename', 'dn', $in{'old'}, { 'new' => $in{'rename'} });
&redirect("edit_browser.cgi?base=".&urlize($in{'base'})."&mode=subs");

