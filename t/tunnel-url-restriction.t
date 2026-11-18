#!/usr/bin/perl
# Check that a configured tunnel URL limits which server and path can be opened.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";

# Compile the real check without initializing the module.
open(my $fh, '<', "$root/tunnel/tunnel-lib.pl") or die $!;
my $code = do { local $/; <$fh> };
close($fh);
$code =~ /(^sub url_allowed\n\{.*?^\})/ms or die "Missing url_allowed";
eval "package tn; no strict; no warnings; $1";
die $@ if $@;
*tn::un_urlize = \&main::un_urlize;

my @allowed = (
	[ 'http://10.0.0.5:10000/', 'http', '10.0.0.5', 10000, '/' ],
	[ 'http://10.0.0.5:10000/', 'http', '10.0.0.5', 10000,
	  '/sysinfo.cgi?xnavigation=1' ],
	[ 'https://Intra.example.com/app/', 'https', 'intra.example.com', 443,
	  '/app/page.html' ],
	[ 'https://intra.example.com/app/index.html', 'https',
	  'intra.example.com', 443, '/app/other.html' ],
	[ 'http://host', 'http', 'host', 80, '/any/path' ],
	[ 'https://host/support%20docs/', 'https', 'host', 443,
	  '/support%20docs/./index.html' ],
	[ 'https://host/C++/', 'https', 'host', 443, '/C++/index.html' ],
	);
foreach my $t (@allowed) {
	ok(tn::url_allowed(@$t), "allows $t->[1]://$t->[2]:$t->[3]$t->[4]");
	}

my @refused = (
	[ 'http://10.0.0.5:10000/', 'http', '127.0.0.1', 8080, '/' ],
	[ 'http://10.0.0.5:10000/', 'https', '10.0.0.5', 10000, '/' ],
	[ 'http://10.0.0.5:10000/', 'http', '10.0.0.5', 10001, '/' ],
	[ 'https://intra.example.com/app/', 'https', 'intra.example.com', 443,
	  '/admin/' ],
	[ 'https://intra.example.com/app/', 'https', 'intra.example.com', 443,
	  '/apple' ],
	[ 'https://intra.example.com/app/', 'https', 'intra.example.com', 443,
	  '/app/../admin/' ],
	[ 'https://intra.example.com/app/', 'https', 'intra.example.com', 443,
	  '/app/%2e%2e/admin/' ],
	[ 'https://intra.example.com/app/', 'https', 'intra.example.com', 443,
	  '/app/..%5cadmin' ],
	[ 'not a url', 'http', 'host', 80, '/' ],
	);
foreach my $t (@refused) {
	ok(!tn::url_allowed(@$t), "refuses $t->[1]://$t->[2]:$t->[3]$t->[4]");
	}

done_testing();
