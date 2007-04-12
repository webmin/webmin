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
	print "<tr> <td><b>$text{'plib_unclients'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=unclients value=allow %s> %s\n",
		$uc eq 'allow' ? "checked" : "", $text{'plib_allow'};
	printf "<input type=radio name=unclients value=deny %s> %s\n",
		$uc eq 'deny' ? "checked" : "", $text{'plib_deny'};
	printf "<input type=radio name=unclients value=ignore %s> %s\n",
		$uc eq 'ignore' ? "checked" : "", $text{'plib_ignore'};
	printf "<input type=radio name=unclients value='' %s> %s\n",
		$uc ? "" : "checked", $text{'default'};
	print "</td> </tr>\n";


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
		print "<tr> <td><b>$text{'plib_clientupdates'}</b></td> <td colspan=3>\n";
		printf "<input type=radio name=clientupdates value=allow %s> %s\n",
			$cu eq 'allow' ? "checked" : "", $text{'plib_allow'};
		printf "<input type=radio name=clientupdates value=deny %s> %s\n",
			$cu eq 'deny' ? "checked" : "", $text{'plib_deny'};
		printf "<input type=radio name=clientupdates value=ignore %s> %s\n",
			$cu eq 'ignore' ? "checked" : "", $text{'plib_ignore'};
		printf "<input type=radio name=clientupdates value='' %s> %s\n",
			$cu ? "" : "checked", $text{'default'};
		print "</td> </tr>\n";

	}
######## END CLIENT-UPDATES #####

	if ($_[1] eq 'subnet' || $_[1] eq 'shared-network' ||
	    $_[1] eq 'global') {
		# Inputs for authoratative
		local $auth = &find("authoritative", $_[0]);
		print "<tr> <td><b>",$text{'plib_auth_'.$_[1]},"</b></td>\n";
		printf "<td><input type=radio name=auth value=1 %s> %s\n",
			$auth ? "checked" : "", $text{'yes'};
		printf "<input type=radio name=auth value=0 %s> %s (%s)</td>\n",
			$auth ? "" : "checked", $text{'default'}, $text{'no'};

		print "</tr>\n";
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

# display_options(&config)
# Display a table of DHCP options
sub display_options
{
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'plib_copt'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
local @opts = &find("option", $_[0]);

print "<tr>\n";
print &p_option_input($text{'plib_chname'}, "host-name", \@opts, 3);
print &p_option_input($text{'plib_defrouters'}, "routers", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &p_option_input($text{'plib_snmask'}, "subnet-mask", \@opts, 0);
print &p_option_input($text{'plib_babbr'}, "broadcast-address", \@opts, 0);
print "</tr>\n";

print "<tr>\n";
print &p_option_input($text{'plib_domname'}, "domain-name", \@opts, 3);
print &p_option_input($text{'plib_dnsserv'}, "domain-name-servers", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &p_option_input($text{'plib_timeserv'}, "time-servers", \@opts, 2);
print &p_option_input($text{'plib_logserv'}, "log-servers", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &p_option_input($text{'plib_swapserv'}, "swap-server", \@opts, 3);
print &p_option_input($text{'plib_rdpath'}, "root-path", \@opts, 3);
print "</tr>\n";

print "<tr>\n";
print &p_option_input($text{'plib_nisdom'}, "nis-domain", \@opts, 3);
print &p_option_input($text{'plib_nisserv'}, "nis-servers", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &p_option_input($text{'plib_fontserv'}, "font-servers", \@opts, 2);
print &p_option_input($text{'plib_xdmserv'}, "x-display-manager", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &p_option_input($text{'plib_statrouters'}, "static-routes", \@opts, 5);
print "</tr>\n";

print "<tr>\n";
print &p_option_input($text{'plib_ntpserv'}, "ntp-servers", \@opts, 2);
print &p_option_input($text{'plib_nbns'}, "netbios-name-servers", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &p_option_input($text{'plib_nbscope'}, "netbios-scope", \@opts, 3);
print &p_option_input($text{'plib_nbntype'}, "netbios-node-type", \@opts, 1);
print "</tr>\n";

print "<tr>\n";
print &p_option_input($text{'plib_toffset'}, "time-offset", \@opts, 1);
print "</tr>\n";

print "</table></td></tr></table>\n";
}

# p_option_input(text, name, &config, type)
# types values:	0  - IP address
#		1  - Integer
#		2  - IP address list
#		3  - String
#		4  - Yes/no flag
#		5  - IP address pairs
sub p_option_input
{
local($rv, $v, $i);
for($i=0; $i<@{$_[2]}; $i++) {
	if ($_[2]->[$i]->{'values'}->[0] eq $_[1]) {
		$v = $_[2]->[$i];
		last;
		}
	}
$rv = "<td><b>$_[0]</b></td>\n";
if ($_[3] == 5) { $rv .= "<td colspan=3>"; }
else { $rv .= "<td>"; }
$rv .= sprintf "<input type=radio name=$_[1]_def value=1 %s> $text{'default'}\n",
	$v ? "" : "checked";
$rv .= sprintf "<input type=radio name=$_[1]_def value=0 %s> ",
	$v ? "checked" : "";
local @vl = $v ? @{$v->{'values'}} : ();
@vl = @vl[1..$#vl];
if ($_[3] == 0) {
	$rv .= "<input name=$_[0] size=15 value=\"$vl[0]\">\n";
	}
elsif ($_[3] == 1) {
	$rv .= "<input name=$_[0] size=8 value=\"$vl[0]\">\n";
	}
elsif ($_[3] == 2) {
	@vl = grep { $_ ne "," } @vl;
	$rv .= "<input name=$_[0] size=25 value=\"".join(" ", @vl)."\">\n";
	}
elsif ($_[3] == 3) {
	local $str = $vl[0] =~ /^[0-9\:]+$/ ? &nvt_to_string($vl[0]) : $vl[0];
	$rv .= "<input name=$_[0] size=20 value=\"$str\">\n";
	}
elsif ($_[3] == 4) {
	$rv .= sprintf "<input name=$_[0] value=1 %s> $text{'yes'}\n",
			$vl[0] eq "1" ? "checked" : "";
	$rv .= sprintf "<input name=$_[0] value=0 %s> $text{'no'}\n",
			$vl[0] eq "0" ? "checked" : "";
	}
elsif ($_[3] == 5) {
	@vl = grep { $_ ne "," } @vl;
	$rv .= "<input name=$_[0] size=50 value=\"";
	for($i=0; $i<@vl; $i+=2) {
		$rv .= $vl[$i]."-".$vl[$i+1];
		}
	$rv .= "\">\n";
	}
$rv .= "</td>\n";
return $rv;
}

1;

