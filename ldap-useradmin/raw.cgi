#!/usr/local/bin/perl
# Show all attributes for a user or group

require './ldap-useradmin-lib.pl';
&ReadParse();
$ldap = &ldap_connect();
$schema = $ldap->schema();
if ($in{'user'}) {
	$rv = $ldap->search(base => $in{'dn'},
			    scope => 'base',
			    filter => &user_filter());
	}
else {
	$rv = $ldap->search(base => $in{'dn'},
			    scope => 'base',
			    filter => &group_filter());
	}
($what) = $rv->all_entries;

&ui_print_header(&text('raw_for', $in{'dn'}), $text{'raw_title'}, "");

foreach $a ($what->attributes()) {
	push(@table, [ "<b>$a</b>",
		       join(" , ", $what->get_value($a)) ]);
	}
print &ui_columns_table([ $text{'raw_name'}, $text{'raw_value'} ],
			100, \@table, undef);

&ui_print_footer($in{'user'} ? ( "edit_user.cgi?dn=".&urlize($in{'dn'}),
				 $text{'uedit_return'} )
			     : ( "edit_group.cgi?dn=".&urlize($in{'dn'}),
				 $text{'gedit_return'} ),
		 "index.cgi?mode=".($in{'user'} ? 'users' : 'groups'),
		 $text{'index_return'});

