#!/usr/local/bin/perl
# search_group.cgi
# Ask the LDAP server to return groups matching some query

require './ldap-useradmin-lib.pl';
&ReadParse();
&useradmin::load_theme_library();	# So that ui functions work

# Do the search
$ldap = &ldap_connect();
$base = &get_group_base();
if ($in{'match'} == 0) {
	$search = "($in{'field'}=$in{'what'})";
	}
elsif ($in{'match'} == 1) {
	$search = "($in{'field'}=*$in{'what'}*)";
	}
elsif ($in{'match'} == 2) {
	$search = "(!($in{'field'}=$in{'what'}))";
	}
elsif ($in{'match'} == 3) {
	$search = "(!($in{'field'}=*$in{'what'}*))";
	}
$rv = $ldap->search(base => $base,
		    filter => "(&".&group_filter().$search.")");
if ($rv->code) {
	&error(&text('search_err', "<tt>$search</tt>",
		     "<tt>$base</tt>", $rv->error));
	}
@groups = $rv->all_entries;

if ($in{'match'} == 6) {
	# Apply less-than filter manually
	@groups = grep { $_->get_value($in{'field'}) < $in{'what'} } @groups;
	}
elsif ($in{'match'} == 7) {
	# Apply greater-than filter manually
	@groups = grep { $_->get_value($in{'field'}) > $in{'what'} } @groups;
	}

&ui_print_header(undef, $text{'search_title'}, "");
if (@groups == 0) {
	print "<p><b>$text{'search_gnotfound'}</b>.<p>\n";
	}
else {
	@glist = map { { &dn_to_hash($_) } } @groups;
	&useradmin::groups_table(\@glist, 0, 1);
	}
&ui_print_footer("", $text{'index_return'});

