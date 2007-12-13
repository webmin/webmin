#!/usr/local/bin/perl
# Delete an entire LDAP object

require './ldap-server-lib.pl';
&error_setup($text{'sdelete_err'});
$access{'browser'} || &error($text{'browser_ecannot'});
&ReadParse();
$ldap = &connect_ldap_db();
ref($ldap) || &error($ldap);
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Get and remove each object
foreach $d (@d) {
	$rv = $ldap->search(base => $d,
			    filter => '(objectClass=*)',
			    scope => 'base');
	if (!$rv || $rv->code) {
		&error(&ldap_error($rv));
		}
	($bo) = $rv->all_entries;
	$bo || &error(&text('sdelete_edn', "<tt>$d</tt>"));

	$rv = $ldap->delete($d);
	if (!$rv || $rv->code) {
		&error(&text('sdelete_edel', "<tt>$d</tt>", &ldap_error($rv)));
		}
	}

# Return to object
if (@d == 1) {
	&webmin_log('delete', 'dn', $d[0]);
	}
else {
	&webmin_log('delete', 'dns', scalar(@d),
		    { 'dn' => \@d });
	}
&redirect("edit_browser.cgi?base=".&urlize($in{'base'})."&mode=subs");
