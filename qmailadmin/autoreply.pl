#!/usr/local/bin/perl
# autoreply.pl
# Simple autoreply script

# read qmail module config
$p = -l $0 ? readlink($0) : $0;
$p =~ /^(.*)\/[^\/]+$/;
open(CONF, "$1/config") || die "Failed to open $1/config";
while(<CONF>) {
	if (/^(\S+)=(.*)/) {
		$config{$1} = $2;
		}
	}
close(CONF);

# read headers and body
while(<STDIN>) {
	s/\r|\n//g;
	if (/^(\S+):\s+(.*)/) {
		$header{lc($1)} = $2;
		}
	elsif (!$_) { last; }
	}
while(<STDIN>) {
	$body .= $_;
	}
if ($header{'x-webmin-autoreply'}) {
	print STDERR "Cancelling autoreply to an autoreply\n";
	exit 1;
	}
if ($header{'x-mailing-list'} ||
    $header{'list-id'} ||
    $header{'precedence'} =~ /junk|bulk|list/i ||
    $header{'to'} =~ /Multiple recipients of/i) {
	# Do nothing if post is from a mailing list
	exit 0;
	}
if ($header{'from'} =~ /postmaster|mailer-daemon/i) {
	# Do nothing if post is a bounce
	exit 0;
	}

# work out the correct to address
@to = ( &split_addresses($header{'to'}),
	&split_addresses($header{'cc'}),
	&split_addresses($header{'bcc'}) );
$to = $to[0]->[0];
foreach $t (@to) {
	if ($t->[0] =~ /^([^\@\s]+)/ && $1 eq $ARGV[1]) {
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

# read the autoreply file
if (open(AUTO, $ARGV[0])) {
	while(<AUTO>) {
		s/\$SUBJECT/$header{'subject'}/g;
		s/\$FROM/$header{'from'}/g;
		s/\$TO/$to/g;
		s/\$DATE/$header{'date'}/g;
		s/\$BODY/$body/g;
		if (/^(\S+):\s*(.*)/ && !$doneheaders) {
			$rheader{$1} = $2;
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
if ($rheader{'Reply-Tracking'}) {
	$track_replies = dbmopen(%replies, $rheader{'Reply-Tracking'}, 0700);
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
			exit(0);
			}
		$replies{$from->[0]} = $now;
		}
	}
delete($rheader{'Reply-Tracking'});
delete($rheader{'Reply-Period'});

# run qmail and feed it the reply
open(MAIL, "|$config{'qmail_dir'}/bin/qmail-inject");
foreach $h (keys %rheader) {
	print MAIL "$h: $rheader{$h}\n";
	}
print MAIL "\n";
print MAIL $rbody;
close(MAIL);

# split_addresses(string)
# Splits a comma-separated list of addresses into [ email, real-name ] pairs
sub split_addresses
{
local (@rv, $str = $_[0]);
while(1) {
	if ($str =~ /^[\s,]*(([^<>\(\)\s]+)\s+\(([^\(\)]+)\))(.*)$/) {
		push(@rv, [ $2, $3, $1 ]);
		$str = $4;
		}
	elsif ($str =~ /^[\s,]*("([^"]+)"\s+<([^\s<>]+)>)(.*)$/ ||
	       $str =~ /^[\s,]*(([^<>]+)\s+<([^\s<>]+)>)(.*)$/ ||
	       $str =~ /^[\s,]*(([^<>\[\]]+)\s+\[mailto:([^\s\[\]]+)\])(.*)$/||
	       $str =~ /^[\s,]*(()<([^\s<>]+)>)(.*)/ ||
	       $str =~ /^[\s,]*(()([^\s<>,]+))(.*)/) {
		push(@rv, [ $3, $2, $1 ]);
		$str = $4;
		}
	else {
		last;
		}
	}
return @rv;
}

