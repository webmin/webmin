# mailserver-monitor.pl
# Check a remote mail server by sending email at period intervals and waiting
# for a response. This depends on the remote address being an autoreponder that
# replies to the sending address with the same or derived subject line.
# XXX other monitors (like net) should be able to do the same thing ..

$alias_name = "webmin-status-mailserver";
$replies_file = "$module_config_directory/mailserver-replies";

sub get_mailserver_status
{
local %oldstatus;
&read_file($oldstatus_file, \%oldstatus);
local $rv = { 'up' => defined($oldstatus{$_[0]->{'id'}}) ?
			$oldstatus{$_[0]->{'id'}} : 1 };
local %replies;
&read_file($replies_file, \%replies);
local ($when, $got, $id) = split(/\s+/, $replies{$_[0]->{'id'}});
local $now = time();
local $timeout = $_[0]->{'timeout'}*($_[0]->{'units'} == 0 ? 1 :
				     $_[0]->{'units'} == 1 ? 60 :
				     $_[0]->{'units'} == 2 ? 60*60 : 24*60*60);
if ($got && $got <= $when + $timeout) {
	# Reply received .. status should be OK
	$rv = { 'up' => 1 };
	}
if ($when + $timeout < $now) {
	# Time has elapsed .. check if we got a response in time
	if ($when && (!$got || $got > $when + $timeout)) {
		# We didn't!
		$rv = { 'up' => 0 };
		}

	# Send a new message, just as the status monitor does
	$id = time().".".$$;
	local $from = "$alias_name\@".&get_system_hostname();
	local $subject = "TEST-$_[0]->{'id'}-$id";
	local $body = "Mail server test";
	if ($config{'sched_smtp'}) {
		# Connect to SMTP server
		&open_socket($config{'sched_smtp'}, 25, MAIL);
		&smtp_command(MAIL);
		&smtp_command(MAIL, "helo ".&get_system_hostname()."\r\n");
		&smtp_command(MAIL, "mail from: <$from>\r\n");
		&smtp_command(MAIL, "rcpt to: <$_[0]->{'to'}>\r\n");
		&smtp_command(MAIL, "data\r\n");
		print MAIL "From: $from\r\n";
		print MAIL "To: $_[0]->{'to'}\r\n";
		print MAIL "Subject: $subject\r\n";
		print MAIL "\r\n";
		print MAIL "$body\r\n";
		&smtp_command(MAIL, ".\r\n");
		&smtp_command(MAIL, "quit\r\n");
		close(MAIL);
		}
	else {
		# Run sendmail executable
		local %sconfig = &foreign_config("sendmail");
		open(MAIL, "|$sconfig{'sendmail_path'} -t -f$from >/dev/null 2>&1");
		print MAIL "From: $from\n";
		print MAIL "To: $_[0]->{'to'}\n";
		print MAIL "Subject: $subject\n";
		print MAIL "\n";
		print MAIL "$body\n";
		print MAIL "\n";
		close(MAIL);

		# Record in file
		$replies{$_[0]->{'id'}} = "$now 0 $id";
		&write_file($replies_file, \%replies);
		}
	}
return $rv;
}

sub show_mailserver_dialog
{
print "<tr> <td colspan=4>$text{'mailserver_desc'}</td> </tr>\n";

print "<tr> <td><b>$text{'mailserver_to'}</b></td>\n";
print "<td><input name=to size=25 value='$_[0]->{'to'}'></td>\n";

print "<td><b>$text{'mailserver_timeout'}</b></td>\n";
print "<td><input name=timeout size=5 value='$_[0]->{'timeout'}'>\n";
print "<select name=units>\n";
for($i=0; defined($text{"mailserver_units_$i"}); $i++) {
	printf "<option value=%s %s>%s</option>\n",
		$i, $_[0]->{'units'} == $i ? "selected" : "",
		$text{"mailserver_units_$i"};
	}
print "</select></td> </tr>\n";
}

sub parse_mailserver_dialog
{
# Parse and save inputs
$in{'to'} =~ /^\S+$/ || &error($text{'mailserver_eto'});
$in{'timeout'} =~ /^\d+$/ || &error($text{'mailserver_etimeout'});
$_[0]->{'to'} = $in{'to'};
$_[0]->{'timeout'} = $in{'timeout'};
$_[0]->{'units'} = $in{'units'};
&depends_check($_[0], "sendmail");

# Set up the alias if needed
&foreign_require("sendmail", "sendmail-lib.pl");
&foreign_require("sendmail", "aliases-lib.pl");
local $conf = &sendmail::get_sendmailcf();
local $afile = &sendmail::aliases_file($conf);
local @aliases = &sendmail::list_aliases($afile);
local ($reply) = grep { $_->{'name'} eq $alias_name } @aliases;

	# We do need to set up a wrapper to call the real mailserver.pl
	local $alias_cmd = "$module_config_directory/mailserver.pl";
	local $perl_path = &get_perl_path();
	&lock_file($alias_cmd);
	open(CMD, ">$alias_cmd");
	print CMD <<EOF;
#!$perl_path
open(CONF, "$config_directory/miniserv.conf") ||
	die "Failed to open miniserv.conf : \$!";
while(<CONF>) {
	\$root = \$1 if (/^root=(.*)/);
	}
close(CONF);
\$ENV{'WEBMIN_CONFIG'} = "$ENV{'WEBMIN_CONFIG'}";
\$ENV{'WEBMIN_VAR'} = "$ENV{'WEBMIN_VAR'}";
chdir("\$root/$module_name");
exec("\$root/$module_name/mailserver.pl", \$ARGV[0]);
EOF
	close(CMD);
	chmod(06755, $alias_cmd);
	&unlock_file($alias_cmd);

if (!$reply) {
	# Create the alias
	local $alias = { 'name' => $alias_name,
			 'values' => [ "|".$alias_cmd ],
			 'enabled' => 1 };
	&sendmail::create_alias($alias, $afile);
	}

local %sconfig = &foreign_config("sendmail");
if (-d $sconfig{'smrsh_dir'}) {
	&system_logged("ln -s $alias_cmd $sconfig{'smrsh_dir'}/mailserver.pl >/dev/null 2>&1");
	}

# Create the file to which replies are written
open(TOUCH, ">>$replies_file");
close(TOUCH);
#chmod(0777, $replies_file);
}

