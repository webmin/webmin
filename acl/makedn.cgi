#!/usr/local/bin/perl
# Create the LDAP base DN

require './acl-lib.pl';
$access{'pass'} || &error($text{'sql_ecannot'});
&get_miniserv_config(\%miniserv);
&ReadParse();
&error_setup($text{'makedn_err'});

$dbh = &connect_userdb($in{'userdb'});
ref($dbh) || &error($dbh);

&ui_print_unbuffered_header(undef, $text{'makedn_title'}, "");

# Work out object class for the DN
($proto, $user, $pass, $host, $prefix, $argstr) =
	&split_userdb_string($in{'userdb'});
$schema = $dbh->schema();
@allocs = map { $_->{'name'} }
           grep { $_->{'structural'} }
                $schema->all_objectclasses();
@ocs = ( );
foreach my $poc ("top", "domain") {
        if (&indexof($poc, @allocs) >= 0) {
                push(@ocs, $poc);
                }
        }
@ocs || &error(&text('makedn_eoc'));

# Create the DN
print &text('makedn_exec', "<tt>$prefix</tt>"),"<br>\n";
@attrs = ( "objectClass", \@ocs );
if (&indexof("domain", @ocs) >= 0 && $prefix =~ /^([^=]+)=([^, ]+)/) {
	# Domain class needs dc
	push(@attrs, $1, $2);
	}
$rv = $dbh->add($prefix, attr => \@attrs);
if (!$rv || $rv->code) {
	print &text('makedn_failed',
		    $rv ? $rv->error : "Unknown error"),"<p>\n";
	}
else {
	print &text('makedn_done'),"<p>\n";
	}
&disconnect_userdb($in{'userdb'}, $dbh);

# Check again if OK
$err = &validate_userdb($in{'userdb'}, 0);
if ($err) {
	print "<b>",&text('makedn_still', $err),"</b><p>\n";
	}
else {
	&lock_file($ENV{'MINISERV_CONFIG'});
	$miniserv{'userdb'} = $in{'userdb'};
	$miniserv{'userdb_addto'} = $in{'addto'};
	&put_miniserv_config(\%miniserv);
	&unlock_file($ENV{'MINISERV_CONFIG'});
	&reload_miniserv();
	}

&ui_print_footer("", $text{'index_return'});

