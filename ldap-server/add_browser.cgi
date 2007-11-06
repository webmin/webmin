#!/usr/local/bin/perl
# Add a new LDAP attribute

require './ldap-server-lib.pl';
&error_setup($text{'add_err'});
&ReadParse();
$ldap = &connect_ldap_db();
ref($ldap) || &error($ldap);

# Get the base object
$rv = $ldap->search(base => $in{'base'},
		     filter => '(objectClass=*)',
		     score => 'base');
if (!$rv || $rv->code) {
	&error($rv ? $rv->code : "Unknown error");
	}
($bo) = $rv->all_entries;
$bo || &error(&text('save_ebase', "<tt>$in{'base'}</tt>"));
$in{'add'} =~ /^\S+$/ || &error($text{'add_eadd'});
$in{'value'} =~ /\S/ || &error($text{'add_evalue'});

# Add the value
$rv = $ldap->modify($bo->dn(),
		    add => { $in{'add'} => $in{'value'} });
if (!$rv || $rv->code) {
	&error(&text('add_emodify', "<tt>".$bo->dn()."</tt>",
				    "<tt>$in{'edit'}</tt>",
				    $rv ? $rv->code : "Unknown error"));
	}

# Return to object
&redirect("edit_browser.cgi?base=".&urlize($in{'base'})."&mode=attrs");
