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
local $conf = &dhcpd::get_config();
local $parent = &dhcpd::get_parent_config();
local @rv;

# Top-level hosts
foreach my $h (&dhcpd::find("host", $conf)) {
	$h->{'parent'} = $parent;
	push(@rv, $h);
	}

# Hosts in groups
foreach my $g (&dhcpd::find("group", $conf)) {
	foreach my $h (&dhcpd::find("host", $g->{'members'})) {
		$h->{'parent'} = $g;
		push(@rv, $h);
		}
	}

# Hosts in subjects, and hosts in groups in subnets
foreach my $s (&dhcpd::find("subnet", $conf)) {
	foreach my $h (&dhcpd::find("host", $s->{'members'})) {
		$h->{'parent'} = $s;
		push(@rv, $h);
		}
	foreach my $g (&dhcpd::find("group", $s->{'members'})) {
		foreach my $h (&dhcpd::find("host", $g->{'members'})) {
			$h->{'parent'} = $g;
			push(@rv, $h);
			}
		}
	}

# All of those, in shared networks
foreach my $n (&dhcpd::find("shared-network", $conf)) {
	# Hosts in shared network
	foreach my $h (&dhcpd::find("host", $n->{'members'})) {
		$h->{'parent'} = $n;
		push(@rv, $h);
		}

	# Hosts in groups
	foreach my $g (&dhcpd::find("group", $n->{'members'})) {
		foreach my $h (&dhcpd::find("host", $g->{'members'})) {
			$h->{'parent'} = $g;
			push(@rv, $h);
			}
		}

	# Hosts in subjects, and hosts in groups in subnets, in shared network
	foreach my $s (&dhcpd::find("subnet", $n->{'members'})) {
		foreach my $h (&dhcpd::find("host", $s->{'members'})) {
			$h->{'parent'} = $s;
			push(@rv, $h);
			}
		foreach my $g (&dhcpd::find("group", $s->{'members'})) {
			foreach my $h (&dhcpd::find("host", $g->{'members'})) {
				$h->{'parent'} = $g;
				push(@rv, $h);
				}
			}
		}
	}

return @rv;
}

# list_dhcp_subnets()
# Returns a list of all DHCP subnet objects
sub list_dhcp_subnets
{
local @rv;
local $conf = &dhcpd::get_config();
local $parent = &dhcpd::get_parent_config();
foreach my $s (&dhcpd::find("subnet", $conf)) {
	$s->{'parent'} = $parent;
	push(@rv, $s);
	}
foreach my $n (&dhcpd::find("shared-network", $conf)) {
	foreach my $s (&dhcpd::find("subnet", $n->{'members'})) {
		$s->{'parent'} = $n;
		push(@rv, $s);
		}
	}
return @rv;
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

# Description
$rv .= &ui_table_row($text{'form_comment'},
	&ui_textbox("comment", $host->{'comment'}, 50));

# Hostname
local $short = &short_hostname($h->{'values'}->[0]);
local $indom = $new || $short ne $h->{'values'}->[0];
$rv .= &ui_table_row($text{'form_host'},
	&ui_textbox("host", $short, 20).
	($indom ? "<tt>.$config{'domain'}</tt>" : ""));
$rv .= &ui_hidden("indom", $indom);

# Fixed IP address
local $fixed = &dhcpd::find("fixed-address", $h->{'members'});
$rv .= &ui_hidden("oldip", $fixed->{'values'}->[0]) if ($fixed);
local @subnets = &list_dhcp_subnets();
local $parsub;
if (!$new) {
	($parsub) = grep { $_ eq $h->{'parent'} } @subnets;
	}
elsif (@subnets) {
	$parsub = $subnets[0];
	}
$rv .= &ui_table_row($text{'form_ip'},
	&ui_textbox("ip", $fixed ? $fixed->{'values'}->[0] : undef, 20).
	($new ? " ".&ip_chooser_button("ip") : "").
	" ".$text{'form_subnet'}." ".
	&ui_select("subnet", $parsub ? $parsub->{'values'}->[0] : '',
		   [ $parsub ? ( ) : ( [ '', $text{'form_nosubnet'} ] ),
		     map { [ $_->{'values'}->[0] ] } @subnets ]));
$rv .= &ui_hidden("oldsubnet", $parsub ? $parsub->{'values'}->[0] : '');

# MAC address
local $hard = &dhcpd::find("hardware", $h->{'members'});
$rv .= &ui_hidden("oldmac", $hard->{'values'}->[1]) if ($hard);
$rv .= &ui_table_row($text{'form_mac'},
#	&ui_select("media", $hard ? $hard->{'values'}->[0] : "ethernet",
#		   [ [ "ethernet", $text{'form_ethernet'} ],
#		     [ "token-ring", $text{'form_tr'} ],
#		     [ "fddi", $text{'form_fddi'} ] ], 1, 0, 1).
        &ui_hidden("media", $hard ? $hard->{'values'}->[0] : "ethernet").
	&ui_textbox("mac", $hard ? $hard->{'values'}->[1] : undef, 20));

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

# get_dns_zone()
# Returns the records file and list of records for the domain
sub get_dns_zone
{
local $conf = &bind8::get_config();
local @zones = &bind8::find("zone", $conf);
foreach my $v (&bind8::find("view", $conf)) {
	push(@zones, &bind8::find("zone", $v->{'members'}));
	}
local ($z) = grep { lc($_->{'value'}) eq lc($config{'domain'}) } @zones;
return ( ) if (!$z);
local $file = &bind8::find("file", $z->{'members'});
local $fn = $file->{'values'}->[0];
local @recs = &bind8::read_zone_file($fn, $config{'domain'});
return ( $fn, \@recs );
}

# get_reverse_dns_zone(ip)
# Returns the records file and list of records for the domain for some IP
sub get_reverse_dns_zone
{
local ($ip) = @_;
local $conf = &bind8::get_config();
local @zones = &bind8::find("zone", $conf);
foreach my $v (&bind8::find("view", $conf)) {
	push(@zones, &bind8::find("zone", $v->{'members'}));
	}
local $arpa = &bind8::ip_to_arpa($ip);
$arpa =~ s/\.$//;
local ($z) = grep { $arpa =~ /\.$_->{'value'}$/i } @zones;
return ( ) if (!$z);
local $file = &bind8::find("file", $z->{'members'});
local $fn = $file->{'values'}->[0];
local @recs = &bind8::read_zone_file($fn, $config{'domain'});
return ( $fn, \@recs, $arpa, $z->{'value'} );
}

sub apply_configuration
{
&lock_file("$module_config_directory/apply");
local $err;
$err = &dhcpd::restart_dhcpd();
if ($err) {
	$err = "DHCPD failed : $err";
	}
else {
	$err = &bind8::restart_bind();
	if ($err) {
		$err = "BIND failed : $err";
		}
	}
&unlock_file("$module_config_directory/apply");
return $err;
}

# ip_chooser_button(field)
sub ip_chooser_button
{
return "<input type=button onClick='ifield = form.$_[0]; chooser = window.open(\"ip_chooser.cgi\", \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,resizable=yes,width=300,height=600\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

1;

