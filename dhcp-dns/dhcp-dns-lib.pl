# Functions for configuring DNS and DHCP servers together

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("bind8", "bind8-lib.pl");
&foreign_require("dhcpd", "dhcpd-lib.pl");

# list_dhcp_hosts()
# Returns a list of DHCP host structures for managed hosts
sub list_dhcp_hosts
{
}

# host_form([&host])
# Returns a form for editing or creating a host
sub host_form
{
local ($h) = @_;
local $new = !$h;
local $rv;
$rv .= &ui_form_start("save.cgi", "post");
if ($new) {
	$rv .= &ui_hidden("new", 1);
	}
else {
	$rv .= &ui_hidden("old", $h->{'values'}->[0]);
	}
$rv .= &ui_table_start($text{'form_header'}, "width=100%", 2);

# Hostname
local $short = &short_hostname($h->{'values'}->[0]);
local $indom = $new || $short eq $h->{'values'}->[0];
$rv .= &ui_table_row($text{'form_host'},
	&ui_textbox("host", $short, 40).
	($indom ? "<tt>.$config{'domain'}</tt>" : ""));
$rv .= &ui_hidden("indom", 1);

# Fixed IP address
local $fixed = &dhcpd::find("fixed-address", $h->{'members'});
$rv .= &ui_table_row($text{'form_ip'},
	&ui_textbox("ip", $fixed ? $fixed->{'values'}->[0] : undef, 20));

# MAC address
local $hard = &dhcpd::find("hardware", $h->{'members'});
$rv .= &ui_table_row($text{'form_mac'},
	&ui_textbox("mac", $hard ? $hard->{'values'}->[0] : undef, 20));

$rv .= &ui_table_end();
if ($new) {
	$rv .= &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	$rv .= &ui_form_end([ [ undef, $text{'save'} ],
			      [ 'delete', $text{'delete'} ] ]);
	}
return $rv;
}

sub short_hostname
{
local ($hn) = @_;
if ($hn =~ /^(\S+)\.\Q$config{'domain'}\E$/) {
	return $1;
	}
else {
	return $hn;
	}
}

1;

