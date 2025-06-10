#!/usr/local/bin/perl
# edit_options.cgi
# XXX +chap options?

require './pptp-server-lib.pl';
$access{'options'} || &error($text{'options_ecannot'});
$out = `pppd --help 2>&1`;
if ($out =~ /version\s+(\S+)/i) {
        $vers = $1;
        }
&ui_print_header(undef, $text{'options_title'}, "", "options", 0, 0, 0, undef, undef, undef,
	&text('options_version', $vers));

$conf = &get_config();
$option = &find_conf("option", $conf);
$option ||= $config{'ppp_options'};
@opts = &parse_ppp_options($option);

if ($option eq $config{'ppp_options'}) {
	print &text('options_desc0', "<tt>$option</tt>"),"\n";
	}
else {
	print &text('options_desc1', "<tt>$option</tt>"),"\n";
	}
print "$text{'options_desc2'}<p>\n";

print "<form action=save_options.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'options_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$lock = &find("lock", \@opts);
print "<tr> <td><b>$text{'options_lock'}</b></td>\n";
printf "<td><input type=radio name=lock value=1 %s> %s\n",
	$lock ? "checked" : "", $text{'yes'};
printf "<input type=radio name=lock value=0 %s> %s</td>\n",
	$lock ? "" : "checked", $text{'no'};

$proxy = &find("proxyarp", \@opts);
print "<td><b>$text{'options_proxyarp'}</b></td>\n";
printf "<td><input type=radio name=proxyarp value=1 %s> %s\n",
	$proxy ? "checked" : "", $text{'yes'};
printf "<input type=radio name=proxyarp value=0 %s> %s</td> </tr>\n",
	$proxy ? "" : "checked", $text{'no'};

$mtu = &find("mtu", \@opts);
printf "<tr> <td><b>$text{'options_mtu'}</b></td> <td>\n";
printf "<input type=radio name=mtu_def value=1 %s> %s\n",
	$mtu ? "" : "checked", $text{'default'};
printf "<input type=radio name=mtu_def value=0 %s>\n",
	$mtu ? "checked" : "";
print "<input name=mtu size=6 value='$mtu->{'value'}'> bytes</td>\n";

$mru = &find("mru", \@opts);
printf "<td><b>$text{'options_mru'}</b></td> <td>\n";
printf "<input type=radio name=mru_def value=1 %s> %s\n",
	$mru ? "" : "checked", $text{'default'};
printf "<input type=radio name=mru_def value=0 %s>\n",
	$mru ? "checked" : "";
print "<input name=mru size=6 value='$mru->{'value'}'> bytes</td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

$auth = &find("auth", \@opts);
$noauth = &find("noauth", \@opts);
print "<tr> <td><b>$text{'options_auth'}</b></td>\n";
printf "<td colspan=3><input type=radio name=auth value=0 %s> %s\n",
	$noauth || $auth ? "" : "checked", $text{'options_auth0'};
printf "<input type=radio name=auth value=1 %s> %s\n",
	$noauth ? "checked" : "", $text{'options_auth1'};
printf "<input type=radio name=auth value=2 %s> %s</td> </tr>\n",
	$auth ? "checked" : "", $text{'options_auth2'};

&auth_input("pap");
&auth_input("chap");

$login = &find("login", \@opts);
print "<tr> <td><b>$text{'options_login'}</b></td>\n";
printf "<td><input type=radio name=login value=1 %s> %s\n",
	$login ? "checked" : "", $text{'yes'};
printf "<input type=radio name=login value=0 %s> %s</td>\n",
	$login ? "" : "checked", $text{'no'};

$name = &find("name", \@opts);
printf "<tr> <td><b>$text{'options_name'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=name_def value=1 %s> %s (%s)\n",
	$name ? "" : "checked", $text{'options_hn'}, &get_system_hostname();
printf "<input type=radio name=name_def value=0 %s>\n",
	$name ? "checked" : "";
print "<input name=name size=30 value='$name->{'value'}'></td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr> <td colspan=4 align=center>$text{'options_msdesc'}</td> </tr>\n";

&foreign_require("pptp-client", "pptp-client-lib.pl");
if (&pptp_client::mppe_support() == 1) {
	# Show new-style MS-CHAP options
	&auth_input("mschap");
	&auth_input("mschap-v2");
	}
else {
	# Show old-style MS-CHAP option
	&auth_input("chapms");
	&auth_input("chapms-v2");
	}

# Show general MPPE options
&pptp_client::mppe_options_form(\@opts);

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

# auth_input(name)
sub auth_input
{
local $a = $_[0];
local $req = &find("require-$a", \@opts);
local $ref = &find("refuse-$a", \@opts);
print "<tr> <td><b>",$text{'options_'.$a},"</b></td> <td colspan=3>\n";
printf "<input type=radio name=$a value=2 %s> %s\n",
	$req ? "checked" : "", $text{"options_req"};
printf "<input type=radio name=$a value=1 %s> %s\n",
	$req || $ref ? "" : "checked", $text{"options_all"};
printf "<input type=radio name=$a value=0 %s> %s</td> </tr>\n",
	$ref ? "checked" : "", $text{"options_ref"};
}

