#!/usr/local/bin/perl
# Actually create a new base DN

require './ldap-server-lib.pl';
&ReadParse();
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

# Work out class for the DN
$schema = $ldap->schema();
@allocs = map { $_->{'name'} }
	   grep { $_->{'structural'} }
		$schema->all_objectclasses();
@ocs = ( );
foreach my $poc ("top", "domain") {
	if (&indexof($poc, @allocs) >= 0) {
		push(@ocs, $poc);
		}
	}
@ocs || &error(&text('create_eoc'));

# Do it, while showing the user
&ui_print_unbuffered_header(undef, $text{'create_title'}, "");

# Create the DN
print &text('create_doingdn', "<tt>".&html_escape($dn)."</tt>"),"<br>\n";
@attrs = ( "objectClass", \@ocs );
if (&indexof("domain", @ocs) >= 0) {
	# Domain class needs dc
	if ($dn =~ /^([^=]+)=([^, ]+)/) {
		push(@attrs, $1, $2);
		}
	}
$rv = $ldap->add($dn, attr => \@attrs);
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
		$edn = "uid=example, ".$dn;
		@attrs = ( "cn", "Example user",
			   "sn", "Example user",
			   "uid", "example",
			   "uidNumber", 9999,
			   "gidNumber", 9999,
			   "loginShell", "/bin/sh",
			   "homeDirectory", "/home/example",
			   "objectClass", [ "posixAccount", "person" ],
			   "userPassword", "*LK*" );
		if ($in{'example'} == 2) {
			# With mail
			push(@attrs, "mail", "example\@example.com");
			}
		}
	elsif ($in{'example'} == 3) {
		# Virtuser
		# XXX not sure about these .. is there any standard?
		$edn = "cn=example\@example.com, ".$dn;
		@attrs = ( "mail", "example\@example.com",
			   "mailForwardingAddress", "example\@somewhere.com",
			   "objectClass", [ "top" ] );
		}
	elsif ($in{'example'} == 4) {
		# Unix group
		$edn = "cn=example, ".$dn;
		@attrs = ( "cn", "example",
			   "gidNumber", 9999,
			   "memberUid", "example",
			   "objectClass", [ "posixGroup" ] );
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

