#!/usr/local/bin/perl
# Update the value(s) of an LDAP attribute

require './ldap-server-lib.pl';
&error_setup($text{'save_err'});
$access{'browser'} || &error($text{'browser_ecannot'});
&ReadParse();
$ldap = &connect_ldap_db();
ref($ldap) || &error($ldap);

# Get the base object
$rv = $ldap->search(base => $in{'base'},
		     filter => '(objectClass=*)',
		     scope => 'base');
if (!$rv || $rv->code) {
	&error(&ldap_error($rv));
	}
($bo) = $rv->all_entries;
$bo || &error(&text('save_ebase', "<tt>$in{'base'}</tt>"));

# Update the values
$in{'value'} =~ s/\r//g;
@values = split(/\n+/, $in{'value'});
@values || &error($text{'save_enone'});
$rv = $ldap->modify($bo->dn(),
		    replace => { $in{'edit'} => \@values });
if (!$rv || $rv->code) {
	&error(&text('save_emodify', "<tt>".$bo->dn()."</tt>",
				     "<tt>$in{'edit'}</tt>",
				     &ldap_error($rv)));
	}

# Return to object
&webmin_log('modify', 'attr', $in{'edit'}, { 'dn' => $in{'base'},
					     'value' => join(" ", @values) });
&redirect("edit_browser.cgi?base=".&urlize($in{'base'})."&mode=attrs");
