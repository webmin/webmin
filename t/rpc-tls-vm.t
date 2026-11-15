#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;

# The live fixture changes a disposable guest and must be explicitly enabled.
plan skip_all => 'Set WEBMIN_RPC_TLS_VM_TEST=1 on a disposable Linux VM'
	unless ($ENV{'WEBMIN_RPC_TLS_VM_TEST'} || '') eq '1';
$^O eq 'linux' && $< == 0 or die 'Disposable root Linux VM required';
# Compare a changed source tree with a separate installation lacking RPC TLS.
my $source = $ENV{'WEBMIN_RPC_TLS_SOURCE'} || "$FindBin::Bin/..";
my $legacy = $ENV{'WEBMIN_RPC_TLS_LEGACY'} or die 'Set WEBMIN_RPC_TLS_LEGACY';
# The Python fixture emits TAP directly and owns its cleanup.
exec('python3', "$FindBin::Bin/fixtures/rpc-tls-live.py", $source, $legacy);
die "Failed to run RPC TLS fixture : $!";
