#!/usr/local/bin/perl
# search_user.cgi
# Ask the LDAP server to return users matching some query

require './ldap-useradmin-lib.pl';
&ReadParse();
&useradmin::load_theme_library();	# So that ui functions work

# Do the search
$ldap = &ldap_connect();
$base = &get_user_base();
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
		    filter => "(&".&user_filter().$search.")");
if ($rv->code) {
	&error(&text('search_err', "<tt>$search</tt>",
		     "<tt>$base</tt>", $rv->error));
	}
@users = $rv->all_entries;

if ($in{'match'} == 6) {
	# Apply less-than filter manually
	@users = grep { $_->get_value($in{'field'}) < $in{'what'} } @users;
	}
elsif ($in{'match'} == 7) {
	# Apply greater-than filter manually
	@users = grep { $_->get_value($in{'field'}) > $in{'what'} } @users;
	}

if ($rv->count == 1) {
	# If one result, go direct to that user
	&redirect("edit_user.cgi?dn=".&urlize($users[0]->dn()));
	}
else {
	# List matching users
	&ui_print_header(undef, $text{'search_title'}, "");
	if (@users == 0) {
		print "<p><b>$text{'search_notfound'}</b>.<p>\n";
		}
	else {
		@ulist = map { { &dn_to_hash($_) } } @users;
		&useradmin::users_table(\@ulist, 0, 1, 0);
		}
	&ui_print_footer("", $text{'index_return'});
	}


