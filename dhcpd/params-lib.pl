#!/usr/bin/perl
# $Id: params-lib.pl,v 1.3 2005/04/16 14:30:21 jfranken Exp $
# * Functions for editing parameters common to many kinds of directive
#
# File modified 2005-04-15 by Johannes Franken <jfranken@jfranken.de>:
# * Added support for the client-update option of dhcpd 3.

# display_params(&config, type)
sub display_params
{
print &ui_hidden("params_type", $_[1]);

print &opt_input($text{'plib_deflt'}, "default-lease-time",
		 $_[0], $text{'default'}, 8, $text{'secs'});
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'plib_bfname'}, "filename", $_[0], $text{'none'}, 20);
print &opt_input($text{'plib_maxlt'}, "max-lease-time",
		 $_[0], $text{'default'}, 8, $text{'secs'});
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'plib_bfserv'}, "next-server", $_[0], $text{'plib_thisserv'}, 15);
print &opt_input($text{'plib_servname'}, "server-name", $_[0], $text{'default'}, 15);
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'plib_llbc'}, "dynamic-bootp-lease-length",
		 $_[0], $text{'plib_forever'}, 8, $text{'secs'});
print &opt_input($text{'plib_lebc'}, "dynamic-bootp-lease-cutoff",
		 $_[0], $text{'plib_never'}, 21);
print "</tr>\n";

if ($config{'dhcpd_version'} >= 3) {
	# Inputs for DDNS
	print "<tr>\n";
	print &choice_input($text{'plib_ddnsup'}, "ddns-updates", $_[0], $text{'yes'}, 'on', $text{'no'}, 'off', $text{'default'}, '');
	print &opt_input($text{'plib_ddnsdom'}, "ddns-domainname", $_[0], $text{'default'}, 15);
	print "</tr>\n";

	print "<tr>\n";
	print &opt_input($text{'plib_ddnsrevdom'}, "ddns-rev-domainname", $_[0], $text{'default'}, 15);
	print &opt_input($text{'plib_ddnshost'}, "ddns-hostname", $_[0], $text{'plib_ddnshost_def'}, 15);
	print "</tr>\n";

	if ($_[1] eq 'global') {
		print "<tr>\n";
		print &wide_choice_input($text{'plib_ddnsupstyle'}, "ddns-update-style", $_[0], $text{'plib_adhoc'}, 'ad-hoc', $text{'plib_interim'}, 'interim', $text{'plib_none'}, 'none', $text{'default'}, '');
		print "</tr>\n";
		}

	# Inputs for allow/deny clients
	local @adi = ( &find("allow", $_[0]), &find("deny", $_[0]),
		       &find("ignore", $_[0]) );
	local ($a, %vals);
	foreach $a (@adi) {
		$vals{$a->{'values'}->[0]} = $a;
		}
	local $uc = $vals{'unknown-clients'}->{'name'};
	print "<tr><td><b>$text{'plib_unclients'}</b></td><td colspan=3>\n";
    print &ui_radio("unclients", $uc,
                          [ [ "allow", $text{'plib_allow'} ],
                            [ "deny", $text{'plib_deny'} ],
                            [ "ignore", $text{'plib_ignore'} ],
                            [ "", $text{'default'} ] ]);
	print "</td></tr>\n";


######## START CLIENT-UPDATES #####
	# Inputs for allow/deny client-updates
	if ($config{'dhcpd_version'} >= 3) {
		local @adi = ( &find("allow", $_[0]), &find("deny", $_[0]),
				   &find("ignore", $_[0]) );
		local ($a, %vals);
		foreach $a (@adi) {
			$vals{$a->{'values'}->[0]} = $a;
			}
		local $cu = $vals{'client-updates'}->{'name'};
		print "<tr><td valign=middle><b>$text{'plib_clientupdates'}</b></td><td valign=middle colspan=3>\n";
        print &ui_radio("clientupdates", $cu,
                          [ [ "allow", $text{'plib_allow'} ],
                            [ "deny", $text{'plib_deny'} ],
                            [ "ignore", $text{'plib_ignore'} ],
                            [ "", $text{'default'} ] ]);

		print "</td> </tr>\n";

	}
######## END CLIENT-UPDATES #####

	if ($_[1] eq 'subnet' || $_[1] eq 'shared-network' ||
	    $_[1] eq 'global') {
		# Inputs for authoratative
		my $auth = &find("authoritative", $_[0]);
		print "<tr><td><b>",$text{'plib_auth_'.$_[1]},"</b></td>\n";
        print "<td>";
        print &ui_yesno_radio("auth", ( $auth ? 1: 0 ), 1, 0);
		print "</td></tr>\n";
		}
	}

}

# parse_params(&parent, [&indent])
sub parse_params
{
# Check for expressions
local $type = $in{'params_type'};
local $c;
foreach $c (@{$_[0]->{'members'}}) {
	if ($c->{'values'}->[0] eq "=") {
		&error(&text('plib_eexpr', "<tt>$c->{'name'}</tt>"));
		}
	}

&save_opt("default-lease-time", \&check_lease, $_[0], $_[1]);
&save_opt("filename", undef, $_[0], $_[1], 1);
&save_opt("max-lease-time", \&check_lease, $_[0], $_[1]);
&save_opt("next-server", \&check_server, $_[0], $_[1]);
&save_opt("server-name", \&check_server, $_[0], $_[1], 1);
&save_opt("dynamic-bootp-lease-length", \&check_lease, $_[0], $_[1]);
&save_opt("dynamic-bootp-lease-cutoff", \&check_ldate, $_[0], $_[1], 1);
if ($config{'dhcpd_version'} >= 3) {
	&save_opt("ddns-domainname", \&check_domain, $_[0], $_[1], 1);
	&save_opt("ddns-rev-domainname", \&check_domain, $_[0], $_[1], 1);
	&save_opt("ddns-hostname", \&check_server, $_[0], $_[1], 1);
	&save_choice("ddns-updates", $_[0], $_[1]);
	if (defined($in{'ddns-update-style'})) {
		&save_choice("ddns-update-style", $_[0], $_[1]);
		}
	local $pm = $_[0]->{'members'};
	local @adi = ( &find("allow", $pm), &find("deny", $pm),
		       &find("ignore", $pm) );
	local ($a, %vals);
	foreach $a (@adi) {
		$vals{$a->{'values'}->[0]} = $a;
		}
	&save_directive($_[0],
		$vals{'unknown-clients'} ? [ $vals{'unknown-clients'} ] : [ ],
		$in{'unclients'} ? [ { 'name' => $in{'unclients'},
				       'values' => [ 'unknown-clients' ] } ]
				 : [ ], $_[1], 1);
	&save_directive($_[0],
		$vals{'client-updates'} ? [ $vals{'client-updates'} ] : [ ],
		$in{'clientupdates'} ? [ { 'name' => $in{'clientupdates'},
				       'values' => [ 'client-updates' ] } ]
				 : [ ], $_[1], 1);
	if (defined($in{'auth'})) {
		if ($in{'auth'}) {
			&save_directive($_[0], "authoritative",
					[ { 'name' => 'authoritative' } ],
					$_[1], 1);
			}
		else {
			&save_directive($_[0], "authoritative", [ ], $_[1]);
			}
		}
	}
}

sub check_lease
{
return $_[0] =~ /^\d+$/ ? undef : "'$_[0]' $text{'plib_invalidlt'}";
}

sub check_server
{
return $_[0] =~ /^\S+$/ ? undef : "'$_[0]' $text{'plib_invalidsn'}";
}

sub check_ldate
{
return $_[0] =~ /^(\d) (\d\d\d\d)\/(\d\d)\/(\d\d) (\d\d):(\d\d):(\d\d)$/ ?
	undef : $text{'plib_leformat'};
}

sub check_domain
{
return $_[0] =~ /^[A-Za-z0-9\.\-]+$/ ? undef : &text('plib_invaliddom', $_[0]);
}

1;

