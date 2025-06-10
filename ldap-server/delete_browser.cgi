#!/usr/local/bin/perl
# Remove several LDAP attributes

require './ldap-server-lib.pl';
&error_setup($text{'delete_err'});
$access{'browser'} || &error($text{'browser_ecannot'});
&ReadParse();
$ldap = &connect_ldap_db();
ref($ldap) || &error($ldap);
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Get the base object
$rv = $ldap->search(base => $in{'base'},
		     filter => '(objectClass=*)',
		     scope => 'base');
if (!$rv || $rv->code) {
	&error(&ldap_error($rv));
	}
($bo) = $rv->all_entries;
$bo || &error(&text('save_ebase', "<tt>$in{'base'}</tt>"));

# Delete the attributes
$rv = $ldap->modify($bo->dn(),
		    delete => \@d);
if (!$rv || $rv->code) {
	&error(&text('delete_emodify', "<tt>".$bo->dn()."</tt>", scalar(@d),
				       &ldap_error($rv)));
	}

# Return to object
if (@d == 1) {
	&webmin_log('delete', 'attr', $d[0], { 'dn' => $in{'base'} });
	}
else {
	&webmin_log('delete', 'attrs', scalar(@d), { 'dn' => $in{'base'} });
	}
&redirect("edit_browser.cgi?base=".&urlize($in{'base'})."&mode=attrs");
