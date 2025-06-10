#!/usr/local/bin/perl
# mailserver.pl
# Called from a sendmail alias when an autoresponse arrives, as sent by the 
# mailserver monitor

$no_acl_check++;
require './status-lib.pl';

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

if ($header{'subject'} =~ /TEST-(\S+)-(\S+)/) {
	# Looks like a valid reply
	local ($sserv, $sid) = ( $1, $2 );
	$replies_file = "$module_config_directory/mailserver-replies";
	&read_file($replies_file, \%replies);
	local ($when, $got, $id) = split(/\s+/, $replies{$sserv});
	if ($id eq $sid) {
		# Got a reply to an outstanding email
		local $now = time();
		$replies{$sserv} = "$when $now $id";
		}
	else {
		# Reply is to an email that is way out of date!
		}
	$replies_file =~ /^(.*)$/;
	&write_file("$1", \%replies);
	exit(0);
	}
else {
	# Unknown email!
	print STDERR "Only Mailserver Response auto-reply messages should be sent to this address\n";
	exit(1);
	}

