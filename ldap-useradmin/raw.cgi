#!/usr/local/bin/perl
# Show all attributes for a user or group

require './ldap-useradmin-lib.pl';
&ReadParse();
$ldap = &ldap_connect();
$schema = $ldap->schema();
if ($in{'user'}) {
	$rv = $ldap->search(base => $in{'dn'},
			    scope => 'base',
			    filter => '(objectClass=posixAccount)');
	}
else {
	$rv = $ldap->search(base => $in{'dn'},
			    scope => 'base',
			    filter => '(objectClass=posixGroup)');
	}
($what) = $rv->all_entries;

&ui_print_header(&text('raw_for', $in{'dn'}), $text{'raw_title'}, "");

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'raw_name'}</b></td>\n";
print "<td><b>$text{'raw_value'}</b></td> </tr>\n";
foreach $a ($what->attributes()) {
	print "<tr $cb> <td><b>$a</b></td>\n";
	print "<td>",(join(" , ", $what->get_value($a)) || "<br>"),"</td>\n";
	print "</tr>\n";
	}
print "</table>\n";

&ui_print_footer($in{'user'} ? ( "edit_user.cgi?dn=".&urlize($in{'dn'}),
				 $text{'uedit_return'} )
			     : ( "edit_group.cgi?dn=".&urlize($in{'dn'}),
				 $text{'gedit_return'} ),
		 "", $text{'index_return'});

