#!/usr/local/bin/perl
# autoreply.pl
# Simple autoreply script. Command line arguments are :
# autoreply-file username alternate-file

# Read sendmail module config
$ENV{'PATH'} = "/bin:/usr/bin:/sbin:/usr/sbin";
$p = -l $0 ? readlink($0) : $0;
$p =~ /^(.*)\/[^\/]+$/;
$moddir = $1;
%config = &read_config_file("$moddir/config");

# If this isn't the sendmail module, try it
if (!$config{'sendmail_path'} || !-x $config{'sendmail_path'}) {
	$moddir =~ s/([^\/]+)$/sendmail/;
	%config = &read_config_file("$moddir/config");
	}

if (!$config{'sendmail_path'} || !-x $config{'sendmail_path'}) {
	# Make some guesses about sendmail
	if (-x "/usr/sbin/sendmail") {
		%config = ( 'sendmail_path' => '/usr/sbin/sendmail' );
		}
	elsif (-x "/usr/local/sbin/sendmail") {
		%config = ( 'sendmail_path' => '/usr/local/sbin/sendmail' );
		}
	elsif (-x "/opt/csw/lib/sendmail") {
		%config = ( 'sendmail_path' => '/opt/csw/lib/sendmail' );
		}
	elsif (-x "/usr/lib/sendmail") {
		%config = ( 'sendmail_path' => '/usr/lib/sendmail' );
		}
	else {
		die "Failed to find sendmail or config file";
		}
	}

# read headers and body
$lnum = 0;
while(<STDIN>) {
	$headers .= $_;
	s/\r|\n//g;
	if (/^From\s+(\S+)/ && $lnum == 0) {
		# Magic From line
		$fromline = $1;
		}
	elsif (/^(\S+):\s+(.*)/) {
		$header{lc($1)} = $2;
		$lastheader = lc($1);
		}
	elsif (/^\s+(.*)/ && $lastheader) {
		$header{$lastheader} .= $_;
		}
	elsif (!$_) { last; }
	$lnum++;
	}
while(<STDIN>) {
	$body .= $_;
	}
if ($header{'x-webmin-autoreply'} ||
    $header{'auto-submitted'} && lc($header{'auto-submitted'}) ne 'no') {
	print STDERR "Cancelling autoreply to an autoreply\n";
	exit 0;
	}
if ($header{'x-spam-flag'} =~ /^Yes/i || $header{'x-spam-status'} =~ /^Yes/i) {
        print STDERR "Cancelling autoreply to message already marked as spam\n";
        exit 0;
        }
if ($header{'x-mailing-list'} ||
    $header{'list-id'} ||
    $header{'precedence'} =~ /junk|bulk|list/i ||
    $header{'to'} =~ /Multiple recipients of/i ||
    $header{'from'} =~ /majordomo/i ||
    $fromline =~ /majordomo/i) {
	# Do nothing if post is from a mailing list
	print STDERR "Cancelling autoreply to message from mailing list\n";
	exit 0;
	}
if ($header{'from'} =~ /postmaster|mailer-daemon/i ||
    $fromline =~ /postmaster|mailer-daemon|<>/ ) {
	# Do nothing if post is a bounce
	print STDERR "Cancelling autoreply to bounce message\n";
	exit 0;
	}

# work out the correct to address
@to = ( &split_addresses($header{'to'}),
	&split_addresses($header{'cc'}),
	&split_addresses($header{'bcc'}) );
$to = $to[0]->[0];
foreach $t (@to) {
	if ($t->[0] =~ /^([^\@\s]+)/ && $1 eq $ARGV[1] ||
	    $t->[0] eq $ARGV[1]) {
		$to = $t->[0];
		}
	}

# build list of default reply headers
$rheader{'From'} = $to;
$rheader{'To'} = $header{'reply-to'} ? $header{'reply-to'}
				     : $header{'from'};
$rheader{'Subject'} = "Autoreply to $header{'subject'}";
$rheader{'X-Webmin-Autoreply'} = 1;
$rheader{'X-Originally-To'} = $header{'to'};
chop($host = `hostname`);
$rheader{'Message-Id'} = "<".time().".".$$."\@".$host.">";

# read the autoreply file (or alternate)
if (open(AUTO, $ARGV[0]) ||
    $ARGV[2] && open(AUTO, $ARGV[2])) {
	while(<AUTO>) {
		s/\$SUBJECT/$header{'subject'}/g;
		s/\$FROM/$header{'from'}/g;
		s/\$TO/$to/g;
		s/\$DATE/$header{'date'}/g;
		s/\$BODY/$body/g;
		if (/^(\S+):\s*(.*)/ && !$doneheaders) {
			if ($1 eq "No-Autoreply-Regexp") {
				push(@no_regexp, $2);
				}
			elsif ($1 eq "Must-Autoreply-Regexp") {
				push(@must_regexp, $2);
				}
			elsif ($1 eq "Autoreply-File") {
				push(@files, $2);
				}
			else {
				$rheader{$1} = $2;
				$rheaders .= $_;
				}
			}
		else {
			$rbody .= $_;
			$doneheaders = 1;
			}
		}
	close(AUTO);
	}
else {
	$rbody = "Failed to open autoreply file $ARGV[0] : $!";
	}

# Open the replies tracking DBM, if one was set
my $rtfile = $rheader{'Reply-Tracking'};
if ($rtfile) {
	$track_replies = dbmopen(%replies, $rtfile, 0700);
	eval { $replies{"test\@example.com"} = 1; };
	if ($@) {
		# DBM is corrupt! Clear it
		dbmclose(%replies);
		unlink($rtfile.".dir");
		unlink($rtfile.".pag");
		unlink($rtfile.".db");
		$track_replies = dbmopen(%replies, $rtfile, 0700);
		}
	}
if ($track_replies) {
	# See if we have replied to this address before
	$period = $rheader{'Reply-Period'} || 60*60;
	($from) = &split_addresses($header{'from'});
	if ($from) {
		$lasttime = $replies{$from->[0]};
		$now = time();
		if ($now < $lasttime+$period) {
			# Autoreplied already in this period .. just halt
			print STDERR "Already autoreplied at $lasttime which ",
				     "is less than $period ago\n";
			exit 0;
			}
		$replies{$from->[0]} = $now;
		}
	}
delete($rheader{'Reply-Tracking'});
delete($rheader{'Reply-Period'});

# Check if we are within the requested time range
if ($rheader{'Autoreply-Start'} && time() < $rheader{'Autoreply-Start'} ||
    $rheader{'Autoreply-End'} && time() > $rheader{'Autoreply-End'}) {
	# Nope .. so do nothing
	print STDERR "Outside of autoreply window of ",
		     "$rheader{'Autoreply-Start'}-$rheader{'Autoreply-End'}\n";
	exit 0;
	}
delete($rheader{'Autoreply-Start'});
delete($rheader{'Autoreply-End'});

# Check if there is a deny list, and if so don't send a reply
@fromsplit = &split_addresses($header{'from'});
if (@fromsplit) {
	$from = $fromsplit[0]->[0];
	($fromuser, $fromdom) = split(/\@/, $from);
	foreach $n (split(/\s+/, $rheader{'No-Autoreply'})) {
		if ($n =~ /^(\S+)\@(\S+)$/ && lc($from) eq lc($n) ||
		    $n =~ /^\*\@(\S+)$/ && lc($fromdom) eq lc($1) ||
		    $n =~ /^(\S+)\@\*$/ && lc($fromuser) eq lc($1) ||
		    $n =~ /^\*\@\*(\S+)$/ && lc($fromdom) =~ /$1$/i ||
		    $n =~ /^(\S+)\@\*(\S+)$/ && lc($fromuser) eq lc($1) &&
						lc($fromdom) =~ /$2$/i) {
			exit(0);
			}
		}
	delete($rheader{'No-Autoreply'});
	}

# Check if message matches one of the deny regexps, or doesn't match a
# required regexp
foreach $re (@no_regexp) {
	if ($re =~ /\S/ && $headers =~ /$re/i) {
		print STDERR "Skipping due to match on $re\n";
		exit(0);
		}
	}
if (@must_regexp) {
	my $found = 0;
	foreach $re (@must_regexp) {
		if ($headers =~ /$re/i) {
			$found++;
			}
		}
	if (!$found) {
		print STDERR "Skipping due to no match on ",
			     join(" ", @must_regexp),"\n";
		exit(0);
		}
	}

# if spamassassin is installed, feed the email to it
$spam = &has_command("spamassassin");
if ($spam) {
	$temp = "/tmp/autoreply.spam.$$";
	unlink($temp);
	open(SPAM, "| $spam >$temp 2>/dev/null");
	print SPAM $headers;
	print SPAM $body;
	close(SPAM);
	$isspam = undef;
	open(SPAMOUT, $temp);
	while(<SPAMOUT>) {
		if (/^X-Spam-Status:\s+Yes/i) {
			$isspam = 1;
			last;
			}
		last if (!/\S/);
		}
	close(SPAMOUT);
	unlink($temp);
	if ($isspam) {
		print STDERR "Not autoreplying to spam\n";
		exit 0;
		}
	}

# Read attached files
foreach $f (@files) {
	local $/ = undef;
	if (!open(FILE, $f)) {
		print STDERR "Failed to open $f : $!\n";
		exit(1);
		}
	$data = <FILE>;
	close(FILE);
	$f =~ s/^.*\///;
	$type = &guess_mime_type($f)."; name=\"$f\"";
	$disp = "inline; filename=\"$f\"";
	push(@attach, { 'headers' => [ [ 'Content-Type', $type ],
				       [ 'Content-Disposition', $disp ],
				       [ 'Content-Transfer-Encoding', 'base64' ]
				     ],
			'data' => $data });
	}

# Work out the content type and encoding
$type = $rbody =~ /<html[^>]*>|<body[^>]*>/i ? "text/html" : "text/plain";
$cs = $rheader{'Charset'};
delete($rheader{'Charset'});
if ($rbody =~ /[\177-\377]/) {
	# High-ascii
	$enc = "quoted-printable";
	$encrbody = &quoted_encode($rbody);
	$type .= "; charset=".($cs || "iso-8859-1");
	}
else {
	$enc = undef;
	$encrbody = $rbody;
	$type .= "; charset=$cs" if ($cs);
	}

# run sendmail and feed it the reply
($rfrom) = &split_addresses($rheader{'From'});
if ($rfrom->[0]) {
	open(MAIL, "|$config{'sendmail_path'} -t -f$rfrom->[0]");
	}
else {
	open(MAIL, "|$config{'sendmail_path'} -t -f$to");
	}
foreach $h (keys %rheader) {
	print MAIL "$h: $rheader{$h}\n";
	}

# Create the message body
if (!@attach) {
	# Just text, so no encoding is needed
	if ($enc) {
		print MAIL "Content-Transfer-Encoding: $enc\n";
		}
	if (!$rheader{'Content-Type'}) {
		print MAIL "Content-Type: $type\n";
		}
	print MAIL "\n";
	print MAIL $encrbody;
	}
else {
	# Need to send a multi-part MIME message
	print MAIL "MIME-Version: 1.0\n";
	$bound = "bound".time();
	$ctype = "multipart/mixed";
	print MAIL "Content-Type: $ctype; boundary=\"$bound\"\n";
	print MAIL "\n";
	$bodyattach = { 'headers' => [ [ 'Content-Type', $type ], ],
			'data' => $encrbody };
	if ($enc) {
		push(@{$bodyattach->{'headers'}},
		     [ 'Content-Transfer-Encoding', $enc ]);
		}
	splice(@attach, 0, 0, $bodyattach);

	# Send attachments
	print MAIL "This is a multi-part message in MIME format.","\n";
	$lnum++;
	foreach $a (@attach) {
		print MAIL "\n";
		print MAIL "--",$bound,"\n";
		local $enc;
		foreach $h (@{$a->{'headers'}}) {
			print MAIL $h->[0],": ",$h->[1],"\n";
			$enc = $h->[1]
				if (lc($h->[0]) eq 'content-transfer-encoding');
			$lnum++;
			}
		print MAIL "\n";
		$lnum++;
		if (lc($enc) eq 'base64') {
			local $enc = &encode_base64($a->{'data'});
			$enc =~ s/\r//g;
			print MAIL $enc;
			}
		else {
			$a->{'data'} =~ s/\r//g;
			$a->{'data'} =~ s/\n\.\n/\n\. \n/g;
			print MAIL $a->{'data'};
			if ($a->{'data'} !~ /\n$/) {
				print MAIL "\n";
				}
			}
		}
	print MAIL "\n";
	print MAIL "--",$bound,"--","\n";
	print MAIL "\n";
	}
close(MAIL);

# split_addresses(string)
# Splits a comma-separated list of addresses into [ email, real-name, original ]
# triplets
sub split_addresses
{
local (@rv, $str = $_[0]);
while(1) {
	if ($str =~ /^[\s,]*(([^<>\(\)\s]+)\s+\(([^\(\)]+)\))(.*)$/) {
		# An address like  foo@bar.com (Fooey Bar)
		push(@rv, [ $2, $3, $1 ]);
		$str = $4;
		}
	elsif ($str =~ /^[\s,]*("([^"]+)"\s*<([^\s<>,]+)>)(.*)$/ ||
	       $str =~ /^[\s,]*(([^<>\@]+)\s+<([^\s<>,]+)>)(.*)$/ ||
	       $str =~ /^[\s,]*(([^<>\@]+)<([^\s<>,]+)>)(.*)$/ ||
	       $str =~ /^[\s,]*(([^<>\[\]]+)\s+\[mailto:([^\s\[\]]+)\])(.*)$/||
	       $str =~ /^[\s,]*(()<([^<>,]+)>)(.*)/ ||
	       $str =~ /^[\s,]*(()([^\s<>,]+))(.*)/) {
		# Addresses like  "Fooey Bar" <foo@bar.com>
		#                 Fooey Bar <foo@bar.com>
		#                 Fooey Bar<foo@bar.com>
		#		  Fooey Bar [mailto:foo@bar.com]
		#		  <foo@bar.com>
		#		  <group name>
		#		  foo@bar.com
		push(@rv, [ $3, $2 eq "," ? "" : $2, $1 ]);
		$str = $4;
		}
	else {
		last;
		}
	}
return @rv;
}

# encode_base64(string)
# Encodes a string into base64 format
sub encode_base64
{
    local $res;
    pos($_[0]) = 0;                          # ensure start at the beginning
    while ($_[0] =~ /(.{1,57})/gs) {
        $res .= substr(pack('u57', $1), 1)."\n";
        chop($res);
    }
    $res =~ tr|\` -_|AA-Za-z0-9+/|;
    local $padding = (3 - length($_[0]) % 3) % 3;
    $res =~ s/.{$padding}$/'=' x $padding/e if ($padding);
    return $res;
}

# guess_mime_type(filename)
sub guess_mime_type
{
local ($file) = @_;
return $file =~ /\.gif/i ? "image/gif" :
       $file =~ /\.(jpeg|jpg)/i ? "image/jpeg" :
       $file =~ /\.txt/i ? "text/plain" :
       $file =~ /\.(htm|html)/i ? "text/html" :
       $file =~ /\.doc/i ? "application/msword" :
       $file =~ /\.xls/i ? "application/vnd.ms-excel" :
       $file =~ /\.ppt/i ? "application/vnd.ms-powerpoint" :
       $file =~ /\.(mpg|mpeg)/i ? "video/mpeg" :
       $file =~ /\.avi/i ? "video/x-msvideo" :
       $file =~ /\.(mp2|mp3)/i ? "audio/mpeg" :
       $file =~ /\.wav/i ? "audio/x-wav" :
			   "application/octet-stream";
}

sub read_config_file
{
local %config;
if (open(CONF, $_[0])) {
	while(<CONF>) {
		if (/^(\S+)=(.*)/) {
			$config{$1} = $2;
			}
		}
	close(CONF);
	}
return %config;
}

# quoted_encode(text)
# Encodes text to quoted-printable format
sub quoted_encode
{
local $t = $_[0];
$t =~ s/([=\177-\377])/sprintf("=%2.2X",ord($1))/ge;
return $t;
}

sub has_command
{
local ($cmd) = @_;
if ($cmd =~ /^\//) {
	return -x $cmd ? $cmd : undef;
	}
else {
	foreach my $d (split(":", $ENV{'PATH'}), "/usr/bin", "/usr/local/bin") {
		return "$d/$cmd" if (-x "$d/$cmd");
		}
	return undef;
	}
}
