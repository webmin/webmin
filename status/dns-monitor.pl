# Check some DNS server

sub get_dns_status
{
if (&has_command("dig")) {
	local $out;
	&execute_command("dig \@".quotemeta($_[0]->{'server'})." ".
			 quotemeta($_[0]->{'host'}), undef, \$out, \$out);
	return $out =~ /\Q$_[0]->{'host'}.\E\s+\S+\s+IN\s+A\s+\Q$_[0]->{'address'}\E/ ? { 'up' => 1 } : { 'up' => 0 };
	}
elsif (&has_command("nslookup")) {
	local $out;
	local $cmd = "server $_[0]->{'server'}\n$_[0]->{'host'}\n";
	&execute_command("nslookup", \$cmd, \$out, \$out);
	return $out =~ /\Q$_[0]->{'address'}\E/ ? { 'up' => 1 }
					        : { 'up' => 0 };
	}
else {
	return { 'up' => - 1 };
	}
}

sub show_dns_dialog
{
print &ui_table_row($text{'dns_server'},
	&ui_textbox("server", $_[0]->{'server'}, 30));

print &ui_table_row($text{'dns_host'},
	&ui_textbox("host", $_[0]->{'host'}, 30));

print &ui_table_row($text{'dns_address'},
	&ui_textbox("address", $_[0]->{'address'}, 30));
}

sub parse_dns_dialog
{
&has_command("nslookup") || &has_command("dig") ||
	&error($text{'dns_ecmds'});
&to_ipaddress($in{'server'}) || &to_ip6address($in{'server'}) ||
	&error($text{'dns_eserver'});
$_[0]->{'server'} = $in{'server'};
$in{'host'} =~ /^[a-z0-9\.\-\_]+$/i || &error($text{'dns_ehost'});
$_[0]->{'host'} = $in{'host'};
&check_ipaddress($in{'address'}) || &error($text{'dns_eaddress'});
$_[0]->{'address'} = $in{'address'};
}

