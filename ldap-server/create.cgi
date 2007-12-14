#!/usr/local/bin/perl
# Actually create a new base DN

require './ldap-server-lib.pl';
&error_setup($text{'create_err'});
$access{'create'} || &error($text{'create_ecannot'});
$ldap = &connect_ldap_db();
ref($ldap) || &error($ldap);

# Validate inputs
if ($in{'mode'} == 0) {
	$in{'domain'} =~ /^[a-z0-9\.\-]+$/ || &error($text{'create_edom'});
	@p = split(/\./, $in{'domain'});
	$dn = join(", ", map { "dc=$_" } @p);
	}
else {
	$in{'dn'} =~ /^\S+=\S+/ || &error($text{'create_edn'});
	$dn = $in{'dn'};
	}

# Do it, while showing the user
&ui_print_unbuffered_header(undef, $text{'create_title'}, "");

# Create the DN
print &text('create_doingdn', "<tt>".&html_escape($dn)."</tt>"),"<br>\n";
$rv = $ldap->add($dn, attr => [ "objectClass", "top" ]);
if (!$rv || $rv->code) {
	print &text('create_edoingdn', &ldap_error($rv)),"<p>\n";
	}
else {
	print $text{'create_done'},"<p>\n";
	$ok = 1;
	}

if ($ok && $in{'example'}) {
	# Add the example user/alias
	if ($in{'example'} == 1 || $in{'example'} == 2) {
		# User
		}
	elsif ($in{'example'} == 3) {
		# Virtuser
		}

	print &text('create_doingex',
		    "<tt>".&html_escape($edn)."</tt>"),"<br>\n";
	$rv = $ldap->add($edn, attr => \@attrs);
	if (!$rv || $rv->code) {
		print &text('create_edoingex', &ldap_error($rv)),"<p>\n";
		}
	else {
		print $text{'create_done'},"<p>\n";
		}
	}

if ($ok) {
	&webmin_log("create", undef, $dn);
	}
&ui_print_footer("", $text{'index_return'});

