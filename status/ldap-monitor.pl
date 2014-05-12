# ldap-monitor.pl
# Try an LDAP ldap on a server

sub get_ldap_status
{
# Check for the Perl module
eval "use Net::LDAP";
if ($@) {
	return { 'up' => -1,
		 'desc' => &text('ldap_edriver', '<tt>Net::LDAP</tt>') };
	}

&foreign_require("ldap-client");
my $err = &ldap_client::generic_ldap_connect($_[0]->{'host'}, $_[0]->{'port'},
					     $_[0]->{'ssl'}, $_[0]->{'user'},
					     $_[0]->{'pass'});
if (!ref($err)) {
	return { 'up' => 0,
		 'desc' => $err };
	}

return { 'up' => 1 };
}

sub show_ldap_dialog
{
print &ui_table_row($text{'ldap_host'},
	&ui_textbox("host", $_[0]->{'host'}, 60), 3);

print &ui_table_row($text{'ldap_port'},
	&ui_opt_textbox("port", $_[0]->{'port'}, 6, $text{'default'}));

print &ui_table_row($text{'ldap_ssl'},
	&ui_yesno_radio("ssl", $_[0]->{'ssl'}), 3);

print &ui_table_row($text{'ldap_user'},
	&ui_textbox("quser", $_[0]->{'user'}, 60), 3);

print &ui_table_row($text{'ldap_pass'},
	&ui_password("qpass", $_[0]->{'pass'}, 20), 3);
}

sub parse_ldap_dialog
{
eval "use Net::LDAP";
return &text('ldap_edriver', '<tt>Net::LDAP</tt>')  if ($@);

&to_ipaddress($in{'host'}) || &to_ip6address($in{'host'}) ||
	&error($text{'ldap_ehost'});
$_[0]->{'host'} = $in{'host'};

$in{'port_def'} || $in{'port'} =~ /^\d+$/ || &error($text{'ldap_eport'});
$_[0]->{'port'} = $in{'port_def'} ? undef : $in{'port'};

$_[0]->{'ssl'} = $in{'ssl'};

$in{'quser'} =~ /^\S*$/ || &error($text{'ldap_euser'});
$_[0]->{'user'} = $in{'quser'};

$in{'qpass'} =~ /^\S*$/ || &error($text{'ldap_epass'});
$_[0]->{'pass'} = $in{'qpass'};
}

