#!/usr/local/bin/perl
# Check the user's LDAP settings

require './ldap-client-lib.pl';
require './switch-lib.pl';
&ui_print_unbuffered_header(undef, $text{'check_title'}, "");

# Get the user base
print $text{'check_base'},"<br>\n";
$conf = &get_config();

@bases = &find_value("base", $conf);
@scopes = &find_value("scope", $conf);

if (&get_ldap_client() eq "nss") {
	# Older LDAP config uses directives like nss_base_passwd, with
	# the scope and filter separated by ?
	$user_base = &find_svalue("nss_base_passwd", $conf) ||
		     &find_svalue("base", $conf);
	}
else {
	# Newer LDAP versions have a base starting with 'user', but fall back
	# to the one with no DB
	($user_base) = map { /^\S+\s+(\S+=*)/; $1 }
		           grep { /^passwd\s/ } @bases;
	if (!$user_base) {
		($user_base) = grep { /^\S+=.*$/ } @bases;
		}
	}
if (!$user_base) {
	&print_problem(&text('check_ebase'));
	goto END;
	}
else {
	print &text('check_based', "<tt>$user_base</tt>"),"<p>\n";
	}

# Attempt to connect to LDAP server
print $text{'check_connect'},"<br>\n";
$ldap = &ldap_connect(1);
if (!ref($ldap)) {
	&print_problem(&text('check_econnect', $ldap));
	goto END;
	}
else {
	local $ldaphost;
	eval { $ldaphost = $ldap->host(); };
	$ldaphost ||= &get_ldap_host();
	print &text('check_connected', $ldaphost),"<p>\n";
	}

# Work out the scope
if (&get_ldap_client() eq "nss") {
	$scope = &find_svalue("scope", $conf);
	}
else {
	($scope) = grep { /^\S+$/ } @scopes;
	}
if ($user_base =~ s/\?([^\?]*)(\?([^\?]*))?$//) {
	$scope = $1;
	}
$scope ||= "one";

# Look for some users
print $text{'check_search'},"<br>\n";
$rv = $ldap->search(base => $user_base,
		    filter => '(objectClass=posixAccount)',
		    scope => $scope);
if ($rv->code) {
	# Search failed!
	&print_problem(&text('check_esearch', $rv->error));
	goto END;
	}
if (!$rv->count) {
	&print_problem(&text('check_eusers', "<tt>$user_base</tt>"));
	goto END;
	}
else {
	print &text('check_found', $rv->count),"<p>\n";
	}

# Check NSS configuration for users
print $text{'check_nss'},"<br>\n";
$nss = &get_nsswitch_config();
($passwd) = grep { $_->{'name'} eq 'passwd' } @$nss;
($ldapsrc) = grep { $_->{'src'} eq 'ldap' ||
		    $_->{'src'} eq 'sss' } @{$passwd->{'srcs'}};
if (!$ldapsrc) {
	&print_problem($text{'check_enss'});
	goto END;
	}
else {
	print $text{'check_nssok'},"<p>\n";
	}

# Make sure one of the users is a valid Unix user
$first = $rv->entry(0);
print &text('check_match', "<tt>".$first->get_value("uid")."</tt>"),"<br>\n";
$uid = getpwnam($first->get_value("uid"));
if (!$uid) {
	# Sometimes this fails due to nsswitch.conf caching .. so try forking
	# a separate command
	$uid = &backquote_command(
		"id -a ".$first->get_value("uid")." 2>/dev/null");
	}
if (!$uid) {
	&print_problem($text{'check_ematch'});
	goto END;
	}
else {
	print $text{'check_matched'},"<p>\n";

	print "<b>$text{'check_done'}</b><p>\n";
	}

END:
&ui_print_footer("", $text{'index_return'});

sub print_problem
{
print "<font color=#ff0000>",@_,"</font><p>\n";
}
