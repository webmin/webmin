# Connect to an IMAP server and login

sub get_imap_status
{
my ($serv) = @_;

my $folder = { 'server' => $serv->{'host'},
	       'port' => $serv->{'port'},
	       'ssl' => $serv->{'ssl'},
	       'user' => $serv->{'user'},
	       'pass' => $serv->{'pass'},
	       'mailbox' => $serv->{'mailbox'} || "INBOX" };
&foreign_require("mailboxes");
my ($st, $h, $count);
eval {
	local $main::error_must_die = 1;
	($st, $h, $count) = &mailboxes::imap_login($folder);
	};
if ($@) {
	# Perl error
	$err = &entities_to_ascii("$@");
	$err =~ s/at\s+\S+\s+line\s+\d+.*//;
	return { 'up' => 0, 'desc' => $err };
	}
elsif ($st == 0) {
	return { 'up' => 0, 'desc' => "Connection failed : $h" };
	}
elsif ($st == 2) {
	return { 'up' => 0, 'desc' => "Login failed : $h" };
	exit(3);
	}
elsif ($st == 3) {
	return { 'up' => 0, 'desc' => "Folder selection failed : $h" };
	}
else {
	return { 'up' => 1, 'desc' => "Login OK, found $count messages" };
	}
}

sub show_imap_dialog
{
my ($serv) = @_;

print &ui_table_row($text{'imap_host'},
	&ui_textbox("host", $serv->{'host'}, 143));

print &ui_table_row($text{'imap_port'},
	&ui_textbox("port", $serv->{'port'} || 25, 5));

print &ui_table_row($text{'imap_ssl'},
	&ui_yesno_radio("ssl", $serv->{'ssl'} || 0));

print &ui_table_row($text{'imap_user'},
	&ui_textbox("user", $serv->{'user'}, 25));

print &ui_table_row($text{'imap_pass'},
	&ui_textbox("pass", $serv->{'pass'}, 25));
}

sub parse_imap_dialog
{
my ($serv) = @_;

&to_ipaddress($in{'host'}) || &to_ip6address($in{'host'}) ||
	&error($text{'imap_ehost'});
$serv->{'host'} = $in{'host'};

$in{'port'} =~ /^\d+$/ || &error($text{'imap_eport'});
$serv->{'port'} = $in{'port'};

$serv->{'ssl'} = $in{'ssl'};

$in{'user'} =~ /\S/ ||  &error($text{'imap_euser'});
$serv->{'user'} = $in{'user'};
$serv->{'pass'} = $in{'pass'};
}

1;

