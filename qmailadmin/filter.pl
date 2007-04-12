#!/usr/local/bin/perl
# filter.pl

# read qmail module config
$p = -l $0 ? readlink($0) : $0;
$p =~ /^(.*)\/[^\/]+$/;
open(CONF, "$1/config");
while(<CONF>) {
	if (/^(\S+)=(.*)/) {
		$config{$1} = $2;
		}
	}
close(CONF);

# read headers and body
$fromline = <STDIN>;
while(<STDIN>) {
	$headers .= $_;
	s/\r|\n//g;
	if (/^(\S+):\s+(.*)/) {
		$header{lc($1)} = $2;
		}
	elsif (!$_) { last; }
	}
while(<STDIN>) {
	$body .= $_;
	}

# read the filter file
if (open(FILTER, $ARGV[0])) {
	while(<FILTER>) {
		s/\r|\n//g;
		if (/^(\S+)\s+(\S+)\s+(\S+)\s+(.*)$/) {
			push(@filter, [ $1, $2, $3, $4 ]);
			}
		elsif (/^(\S+)\s+(\S+)$/) {
			push(@filter, [ $1, $2 ]);
			}
		}
	close(FILTER);
	}
else {
	print STDERR "Filter file $ARGV[0] does not exist!\n";
	exit 1;
	}

# run the filter to find the first matching rule
open(LOG, ">>$ARGV[0].log");
foreach $f (@filter) {
	local $field = $f->[2] eq 'body' ? $body : $header{$f->[2]};
	local $st = 0;
	if ($f->[0] == 0) {
		$st = ($field !~ /$f->[3]/i);
		}
	elsif ($f->[0] == 1) {
		$st = ($field =~ /$f->[3]/i);
		}
	elsif ($f->[0] == 2) {
		$st = 1;
		}
	if ($st) {
		# The rule matched!
		if ($f->[1] =~ /^\//) {
			# Write to a file
			open(MAIL, ">>$f->[1]");
			print MAIL $fromline;
			}
		else {
			# Forward to another address
			$f->[1] =~ s/\\/\\\\/g;
			$f->[1] =~ s/'/\\'/g;
			open(MAIL, "|$config{'qmail_dir'}/bin/qmail-inject '$f->[1]'");
			}
		print MAIL $headers;
		print MAIL $body;
		close(MAIL);
		$now = localtime(time());
		print LOG "[$now] [$header{'from'}] [",join(" ",@$f),"]\n";
		last;
		}
	}

