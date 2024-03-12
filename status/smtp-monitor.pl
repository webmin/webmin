# Connect to an SMTP server, login and try to send a message

sub get_smtp_status
{
my ($serv) = @_;

&foreign_require("mailboxes");
$main::error_must_die = 1;
my $desc;
eval {
	my $h = { 'fh' => 'MAIL' };
        &open_socket($serv->{'host'}, $serv->{'port'}, $h->{'fh'});
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
	$desc = $text{'smtp_ok1'};

	# Open an SMTP transaction
	if ($serv->{'from'}) {
		&mailboxes::smtp_command($h, "mail from: <$serv->{'from'}>\r\n");
		$desc = $text{'smtp_ok2'};
		}
	if ($serv->{'to'}) {
		&mailboxes::smtp_command($h, "rcpt to: <$serv->{'to'}>\r\n");
		$desc = $text{'smtp_ok3'};
		}
	&mailboxes::smtp_command($h, "quit\r\n");
	&close_http_connection($h);
	};
if ($@) {
        $err = &entities_to_ascii("$@");
        $err =~ s/at\s+\S+\s+line\s+\d+.*//;
	return { 'up' => 0,
		 'desc' => $err };
	}
return { 'up' => 1, 'desc' => $desc };
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
	&ui_textbox("port", $serv->{'port'} || 25, 5));

print &ui_table_row($text{'smtp_ssl'},
	&ui_radio("ssl", $serv->{'ssl'} || 0,
		  [ [ 0, $text{'smtp_ssl0'} ],
		    [ 1, $text{'smtp_ssl1'} ],
		    [ 2, $text{'smtp_ssl2'} ] ]));

print &ui_table_row($text{'smtp_from'},
	&ui_opt_textbox("from", $serv->{'from'}, 25,
			$text{'smtp_none'}, $text{'smtp_addr'}));

print &ui_table_row($text{'smtp_to'},
	&ui_opt_textbox("to", $serv->{'to'}, 25,
			$text{'smtp_none'}, $text{'smtp_addr'}));
}

sub parse_smtp_dialog
{
my ($serv) = @_;

&to_ipaddress($in{'host'}) || &to_ip6address($in{'host'}) ||
	&error($text{'smtp_ehost'});
$serv->{'host'} = $in{'host'};

$in{'port'} =~ /^\d+$/ || &error($text{'smtp_eport'});
$serv->{'port'} = $in{'port'};

$serv->{'ssl'} = $in{'ssl'};

if ($in{'from_def'}) {
	delete($serv->{'from'});
	}
else {
	$in{'from'} =~ /^\S+\@\S+$/ || &error($text{'smtp_efrom'});
	$serv->{'from'} = $in{'from'};
	}

if ($in{'to_def'}) {
	delete($serv->{'to'});
	}
else {
	$in{'to'} =~ /^\S+\@\S+$/ || &error($text{'smtp_eto'});
	$serv->{'to'} = $in{'to'};
	}
}

1;

