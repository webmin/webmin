#!/usr/local/bin/perl
# Send the webmin feedback form

BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
if (&get_product_name() eq 'usermin') {
	&switch_to_remote_user();
	}
&ReadParseMime();
&error_setup($text{'feedback_err'});
%access = &get_module_acl();
$access{'feedback'} || &error($text{'feedback_ecannot'});

# Construct the email body
$in{'text'} =~ s/\r//g;
$date = localtime(time());
$ver = &get_webmin_version();
if ($in{'name'} && $in{'email'}) {
	$from = "$in{'name'} <$in{'email'}>";
	$email = $in{'email'};
	}
elsif ($in{'email'}) {
	$email = $from = $in{'email'};
	}
else {
	$email = $from = "feedback\@".&get_system_hostname();
	}
local $m = $in{'module'};
$m || !$in{'config'} || &error($text{'feedback_emodule'});
&check_os_support($m) && $m !~ /\.\./ || &error($text{'feedback_emodule2'});
if ($m) {
	%minfo = &get_module_info($m);
	$ver .= " (Module: $minfo{'version'})" if ($minfo{'version'});
	$module = "$m ($minfo{'desc'})";
	}
else {
	$module = "None";
	}
if ($gconfig{'nofeedbackcc'}) {
	@tolist = ( $gconfig{'feedback_to'} ||
		    $minfo{'feedback'} ||
		    $webmin_feedback_address );
	}
else {
	@tolist = split(/\s+/, $in{'to'});
	}
@tolist || &error($text{'feedback_enoto'});
foreach $t (@tolist) {
	$headers .= "To: $t\n";
	}
$headers .= "From: $from\n";
$headers .= "Subject: $text{'feedback_title'}\n";

$attach[0] = <<EOF;
Content-Type: text/plain
Content-Transfer-Encoding: 7bit

Name:           $in{'name'}
Email address:  $in{'email'}
Date:           $date
Webmin version: $ver
Perl version:   $]
Module:         $module
Browser:        $ENV{'HTTP_USER_AGENT'}
EOF

if ($in{'os'}) {
	$uname = `uname -a`;
	$attach[0] .= <<EOF;
OS from webmin: $gconfig{'real_os_type'} $gconfig{'real_os_version'}
OS code:        $gconfig{'os_type'} $gconfig{'os_version'}
Uname output:   $uname
EOF
	}

$attach[0] .= "\n".$in{'text'}."\n";

if ($in{'config'} && !$gconfig{'nofeedbackconfig'}) {
	# Check if this user has full rights to the module
	$access{'feedback'} >= 2 || &error($text{'feedback_ecannot2'});
	local %uacl = &get_module_acl(undef, $m);
	local %defacl;
	local $mdir = &module_root_directory($m);
	&read_file("$mdir/defaultacl", \%defacl);
	if ($access{'feedback'} != 3) {
		foreach $k (keys %uacl) {
			if ($defacl{$k} ne $uacl{$k}) {
				&error($text{'feedback_econfig'});
				}
			}
		}

	# Attach all the text file from the module's config
	local %mconfig = &foreign_config($m);
	if (keys %mconfig) {
		local $a;
		$a .= "Content-Type: text/plain; name=\"config\"\n";
		$a .= "Content-Transfer-Encoding: 7bit\n";
		$a .= "\n";
		foreach $k (keys %mconfig) {
			$a .= "$k=$mconfig{$k}\n";
			}
		push(@attach, $a);
		}

	# Find out what config files the module uses
	local @files;
	if (-r "$mdir/feedback_files.pl") {
		# Ask the module for it's files
		&foreign_require($m, "feedback_files.pl");
		@files = &foreign_call($m, "feedback_files", $m);
		}

	# Use all the path in the config
	foreach $k (keys %mconfig) {
		push(@files, $mconfig{$k}) if ($mconfig{$k} =~ /^\//);
		}
	@files = &unique(@files);

	# Attach those config files that are plain text (less than 5%
	# non-ascii characters). Also skip logfiles.
	foreach $f (@files) {
		next if (!$f || -d $f);
		next if ($f =~ /\/var\/log\//);
		local $/ = undef;
		open(FILE, "<$f") || next;
		local $data = <FILE>;
		close(FILE);
		local $count = ($data =~ tr/[\000-\176]/[\000-\176]/);
		if (!length($data) || 100*$count / length($data) > 95) {
			# File is text
			local $a;
			local $sf = &short_name($f);
			$a .= "Content-Type: text/plain; name=\"$sf\"\n";
			$a .= "Content-Transfer-Encoding: 7bit\n";
			$a .= "\n";
			$a .= $data;
			push(@attach, $a);
			}
		}
	}

# Include uploaded attached files
foreach $u ('attach0', 'attach1') {
	if ($in{$u} ne '') {
		local $a;
		local $name = &short_name($in{"${u}_filename"});
		local $type = $in{"${u}_content_type"};
		$type = &guess_mime_type($name) if (!$type);
		$a .= "Content-type: $type; name=\"$name\"\n";
		$a .= "Content-Transfer-Encoding: base64\n";
		$a .= "\n\n";
		$a .= &encode_base64($in{$u});
		push(@attach, $a);
		}
	}

# Build the MIME email
$bound = "bound".time();
$mail = $headers;
$mail .= "Content-Type: multipart/mixed; boundary=\"$bound\"\n";
$mail .= "MIME-Version: 1.0\n";
$mail .= "\n";
$mail .= "This is a multi-part message in MIME format.\n";
foreach $a (@attach) {
	$mail .= "\n--".$bound."\n";
	$mail .= $a;
	}
$mail .= "\n--".$bound."--\n";

if (!$in{'mailserver_def'}) {
	$ok = &send_via_smtp($in{'mailserver'});
	$sent = 3 if ($ok);
	}

if (!$sent) {
	# Try to send the email by calling sendmail -t
	%sconfig = &foreign_config("sendmail");
	$sendmail = $sconfig{'sendmail_path'} ? $sconfig{'sendmail_path'}
					      : &has_command("sendmail");
	if (-x $sendmail && open(MAIL, "| $sendmail -t")) {
		print MAIL $mail;
		if (close(MAIL)) {
			$sent = 2;
			}
		}
	}

if (!$sent) {
	# Try to connect to a local SMTP server
	$ok = &send_via_smtp("localhost");
	$sent = 1 if ($ok);
	}

if ($sent) {
	# Tell the user that it was sent OK
	&ui_print_header(undef, $text{'feedback_title'}, "", undef, 0, 1);
	if ($sent == 3) {
		print &text('feedback_via', join(",", @tolist),
			    "<tt>$in{'mailserver'}</tt>"),"\n";
		}
	elsif ($sent == 2) {
		print &text('feedback_prog', join(",", @tolist),
			    "<tt>$sendmail</tt>"),"\n";
		}
	else {
		print &text('feedback_via', join(",", @tolist),
			    "<tt>localhost</tt>"),"\n";
		}
	print "<p>\n";
	&ui_print_footer("/", $text{'index'});

	# Save settings in config
	$gconfig{'feedback_name'} = $in{'name'};
	$gconfig{'feedback_email'} = $in{'email'};
	$gconfig{'feedback_mailserver'} =
		$in{'mailserver_def'} ? undef : $in{'mailserver'};
	&write_file("$config_directory/config", \%gconfig);
	}
else {
	# Give up! Tell the user ..
	&error($text{'feedback_esend'});
	}

sub send_via_smtp
{
local $error;
&open_socket($_[0], 25, MAIL, \$error);
return 0 if ($error);
&smtp_command(MAIL) || return 0;
&smtp_command(MAIL, "helo ".&get_system_hostname()."\r\n") || return 0;
&smtp_command(MAIL, "mail from: <$email>\r\n") || return 0;
foreach $t (@tolist) {
	&smtp_command(MAIL, "rcpt to: <$t>\r\n") || return 0;
	}
&smtp_command(MAIL, "data\r\n");
$mail =~ s/\r//g;
$mail =~ s/\n/\r\n/g;
print MAIL $mail;
&smtp_command(MAIL, ".\r\n");
&smtp_command(MAIL, "quit\r\n");
close(MAIL);
return 1;
}

# smtp_command(handle, command)
sub smtp_command
{
local ($m, $c) = @_;
print $m $c;
local $r = <$m>;
return $r =~ /^[23]\d+/;
}

sub short_name
{
$_[0] =~ /([^\\\/]+)$/;
return $1;
}

