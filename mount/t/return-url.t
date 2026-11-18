#!/usr/bin/perl
# Checks that the mount module only returns to pages on the same server.

use strict;
use warnings;
use Test::More;
use FindBin;

# Load only the helper, without module startup
open(my $lib, '<', "$FindBin::Bin/../mount-lib.pl") or die $!;
my $source = do { local $/; <$lib> };
close($lib);
my ($code) = $source =~ /^(sub local_return_url\n\{.*?^\})/ms;
die 'Missing local_return_url' if (!$code);
eval "no strict; $code";
die $@ if ($@);

is(local_return_url('/format/'), '/format/', 'absolute local path is kept');
is(local_return_url('../fdisk/edit_part.cgi?disk=0&part=1'),
   '../fdisk/edit_part.cgi?disk=0&part=1', 'relative path is kept');
is(local_return_url(''), '', 'empty link stays empty');
foreach my $bad ('https://evil.example/', '//evil.example/',
		 '/\\evil.example/', 'javascript:alert(1)',
		 ' JavaScript:alert(1)', "/x\r\nLocation: http://evil/") {
	is(local_return_url($bad), '', "unsafe link is dropped: $bad");
	}

done_testing();
