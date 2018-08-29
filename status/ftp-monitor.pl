# ftp-monitor.pl
# Monitor a remote FTP server by doing a test download

sub get_ftp_status
{
local $up = 0;
local $st = time();
local $error;
local $temp = &transname();
eval {
	local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
	alarm($_[0]->{'alarm'} ? $_[0]->{'alarm'} : 10);

	if ($_[0]->{'tls'}) {
		# Connect using TLS-capable perl module
		eval "use Net::FTPSSL";
		my $ftps;
		eval { $ftps = Net::FTPSSL->new($_[0]->{'host'},
					    Port => $_[0]->{'port'} || 21) };
		if ($@) {
			$error = &text('ftp_econn2', &html_escape($@));
			return 0;
			}
		elsif (!$ftps) {
			$error = $text{'ftp_econn'};
			return 0;
			}

		# Login with username and password, or anonymous
		my $ok;
		if ($_[0]->{'user'}) {
			$ok = $ftps->login($_[0]->{'user'}, $_[0]->{'pass'});
			}
		else {
			$ok = $ftps->login("anonymous",
				     "root\@".&get_system_hostname());
			}
		if (!$ok) {
			$error = &text('ftp_elogin', $ftps->last_message);
			return 0;
			}

		# Get the file
		if ($_[0]->{'file'}) {
			$ok = $ftps->get($_[0]->{'file'}, $temp);
			if (!$ok) {
				$error = &text('ftp_etlsfile',
					       $ftps->last_message);
				return 0;
				}
			}
		$ftps->quit();
		}
	else {
		# Use Webmin's built in FTP code
		&ftp_download($_[0]->{'host'}, $_[0]->{'file'}, $temp, \$error,
			      undef, $_[0]->{'user'}, $_[0]->{'pass'},
			      $_[0]->{'port'}, 0, 0);
		}
	alarm(0);
	$up = $error ? 0 : 1;
	};

if ($@) {
	die unless $@ eq "alarm\n";   # propagate unexpected errors
	return { 'up' => 0 };
	}
else { 
	return { 'up' => $up, 'time' => time() - $st,
		 'desc' => $up ? undef : $error };
	}
}

sub show_ftp_dialog
{
print &ui_table_row($text{'ftp_host'},
	&ui_textbox("host", $_[0]->{'host'}, 30));

print &ui_table_row($text{'ftp_port'},
	&ui_textbox("port", $_[0]->{'port'} || 21, 5));

print &ui_table_row($text{'ftp_user'},
	&ui_opt_textbox("ftpuser", $_[0]->{'user'}, 15, $text{'ftp_anon'}));

print &ui_table_row($text{'ftp_pass'},
	&ui_password("ftppass", $_[0]->{'pass'}, 15));

print &ui_table_row($text{'ftp_file'},
	&ui_opt_textbox("file", $_[0]->{'file'}, 50, $text{'ftp_none'}), 3);

print &ui_table_row($text{'http_alarm'},
	&ui_opt_textbox("alarm", $_[0]->{'alarm'}, 5, $text{'default'}));

print &ui_table_row($text{'ftp_tls'},
	&ui_yesno_radio("tls", $_[0]->{'tls'}));
}

sub parse_ftp_dialog
{
$in{'host'} =~ /^[a-z0-9\.\-\_]+$/i || &error($text{'ftp_ehost'});
$_[0]->{'host'} = $in{'host'};

$in{'port'} =~ /^\d+$/i || &error($text{'ftp_eport'});
$_[0]->{'port'} = $in{'port'};

$in{'ftpuser_def'} || $in{'ftpuser'} =~ /^\S+$/ || &error($text{'ftp_euser'});
$_[0]->{'user'} = $in{'ftpuser_def'} ? undef : $in{'ftpuser'};
$_[0]->{'pass'} = $in{'ftppass'};

$in{'file_def'} || $in{'file'} =~ /^\S+$/ || &error($text{'ftp_efile'});
$_[0]->{'file'} = $in{'file_def'} ? undef : $in{'file'};

if ($in{'alarm_def'}) {
	delete($_[0]->{'alarm'});
	}
else {
	$in{'alarm'} =~ /^\d+$/ || &error($text{'http_ealarm'});
	$_[0]->{'alarm'} = $in{'alarm'};
	}

$_[0]->{'tls'} = $in{'tls'};
if ($in{'tls'}) {
	eval "use Net::FTPSSL";
	if ($@) {
		&error(&text('ftp_etls', '<tt>Net::FTPSSL</tt>'));
		}
	}
}

