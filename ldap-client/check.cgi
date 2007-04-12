#!/usr/local/bin/perl
# Check the user's LDAP settings

require './ldap-client-lib.pl';
require './switch-lib.pl';
&ui_print_unbuffered_header(undef, $text{'check_title'}, "");

# Get the user base
print $text{'check_base'},"<br>\n";
$conf = &get_config();
$user_base = &find_svalue("nss_base_passwd", $conf) ||
	     &find_svalue("base", $conf);
if (!$user_base) {
	print &text('check_ebase'),"<p>\n";
	goto END;
	}
else {
	print &text('check_based', "<tt>$user_base</tt>"),"<p>\n";
	}

# Attempt to connect to LDAP server
print $text{'check_connect'},"<br>\n";
$ldap = &ldap_connect(1, \$host);
if (!ref($ldap)) {
	print &text('check_econnect', $ldap),"<p>\n";
	goto END;
	}
else {
	print &text('check_connected', $host),"<p>\n";
	}

# Work out the scope
$scope = &find_svalue("scope", $conf);
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
	print &text('check_esearch', $rv->error),"<p>\n";
	goto END;
	}
if (!$rv->count) {
	print &text('check_eusers', "<tt>$user_base</tt>"),"<p>\n";
	goto END;
	}
else {
	print &text('check_found', $rv->count),"<p>\n";
	}

# Check NSS configuration for users
print $text{'check_nss'},"<br>\n";
$nss = &get_nsswitch_config();
($passwd) = grep { $_->{'name'} eq 'passwd' } @$nss;
($ldapsrc) = grep { $_->{'src'} eq 'ldap' } @{$passwd->{'srcs'}};
if (!$ldapsrc) {
	print $text{'check_enss'},"<p>\n";
	goto END;
	}
else {
	print $text{'check_nssok'},"<p>\n";
	}

# Make sure one of the users is a valid Unix user
$first = $rv->entry(0);
print &text('check_match', "<tt>".$first->get_value("uid")."</tt>"),"<br>\n";
@uinfo = getpwnam($first->get_value("uid"));
if (!@uinfo) {
	print $text{'check_ematch'},"<p>\n";
	goto END;
	}
else {
	print $text{'check_matched'},"<p>\n";

	print "<b>$text{'check_done'}</b><p>\n";
	}

END:
&ui_print_footer("", $text{'index_return'});
