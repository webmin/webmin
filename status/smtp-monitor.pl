# Connect to an SMTP server, login and try to send a message

sub get_smtp_status
{
my ($serv) = @_;

&foreign_require("mailboxes");
$main::error_must_die = 1;
eval {
	my $h = { 'fh' => 'MAIL' };
        &open_socket($server, $port, $h->{'fh'});
	if ($serv->{'ssl'} == 1) {
                # Switch to SSL mode right now
                &switch_smtp_to_ssl($h);
		}
	my $callpkg = (caller(0))[0];
        $h->{'fh'} = $callpkg."::".$h->{'fh'};
	&mailboxes::smtp_command($h);
        &mailboxes::smtp_command($h, "helo ".&get_system_hostname()."\r\n");
	if ($ssl == 2) {
                # Switch to SSL with STARTTLS
                my $rv = &mailboxes::smtp_command($h, "starttls\r\n", 1);
                if ($rv =~ /^2\d+/) {
                        &switch_smtp_to_ssl($h);
                        }
                else {
                        $serv->{'ssl'} = 0;
                        }
                }
	# XXX
	};
if ($@) {
        $err = &entities_to_ascii(&html_tags_to_text("$@"));
        $err =~ s/at\s+\S+\s+line\s+\d+.*//;
	return { 'up' => 0,
		 'desc' => $err };
	}
return { 'up' => 1 };
}

sub switch_smtp_to_ssl
{
my ($h) = @_;
eval "use Net::SSLeay";
$@ && die($text{'link_essl'});
eval "Net::SSLeay::SSLeay_add_ssl_algorithms()";
eval "Net::SSLeay::load_error_strings()";
$h->{'ssl_ctx'} = Net::SSLeay::CTX_new() ||
        die("Failed to create SSL context");
$h->{'ssl_con'} = Net::SSLeay::new($h->{'ssl_ctx'}) ||
        die("Failed to create SSL connection");
Net::SSLeay::set_fd($h->{'ssl_con'}, fileno(MAIL));
Net::SSLeay::connect($h->{'ssl_con'}) ||
        die("SSL connect() failed");
}

sub show_smtp_dialog
{
my ($serv) = @_;

print &ui_table_row($text{'smtp_host'},
	&ui_textbox("host", $serv->{'host'}, 25));

print &ui_table_row($text{'smtp_port'},
	&ui_textbox("port", $serv->{'port'}, 5));
}

sub parse_tcp_dialog
{
my ($serv) = @_;

&to_ipaddress($in{'host'}) || &to_ip6address($in{'host'}) ||
	&error($text{'smtp_ehost'});
$serv->{'host'} = $in{'host'};

$in{'port'} =~ /^\d+$/ || &error($text{'smtp_eport'});
$serv->{'port'} = $in{'port'};
}

1;

