#!/usr/local/bin/perl
# Show all attributes for a user or group

require './ldap-useradmin-lib.pl';
&ReadParse();
$ldap = &ldap_connect();
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
$what || &error($text{'uedit_egone'});
my %entry = &dn_to_hash($what);
($in{'user'} ? &can_edit_user(\%entry) : &can_edit_group(\%entry)) ||
	&error($text{$in{'user'} ? 'uedit_eedit' : 'gedit_eedit'});

&ui_print_header(&text('raw_for', &html_escape($in{'dn'})), $text{'raw_title'}, "");

foreach $a ($what->attributes()) {
	push(@table, [ "<b>".&html_escape($a)."</b>",
		       join(" , ", map { &html_escape($_) } $what->get_value($a)) ]);
	}
print &ui_columns_table([ $text{'raw_name'}, $text{'raw_value'} ],
			100, \@table, undef);

&ui_print_footer($in{'user'} ? ( "edit_user.cgi?dn=".&urlize($in{'dn'}),
				 $text{'uedit_return'} )
			     : ( "edit_group.cgi?dn=".&urlize($in{'dn'}),
				 $text{'gedit_return'} ),
		 "index.cgi?mode=".($in{'user'} ? 'users' : 'groups'),
		 $text{'index_return'});

