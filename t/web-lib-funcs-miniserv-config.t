#!/usr/bin/perl
# Concurrent WebSocket updates must not reuse a same-second config snapshot.
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Spec;

require File::Spec->rel2abs(dirname(__FILE__).'/../web-lib-funcs.pl');
my $directory = tempdir(CLEANUP => 1);
my $file = "$directory/miniserv.conf";
{
	no warnings qw(redefine once);
	*main::get_miniserv_config_file = sub { return $file; };
}

# replace_config(contents) simulates another process writing within one second.
sub replace_config
{
my ($contents) = @_;
open(my $fh, '>', $file) or die $!;
print {$fh} $contents;
close($fh) or die $!;
utime(1700000000, 1700000000, $file) or die $!;
}

replace_config("port=10000\nwebsockets_/test/ws-555=first\n");
my %first;
ok(main::get_miniserv_config(\%first), 'read initial configuration');
is($first{'websockets_/test/ws-555'}, 'first', 'first route is present');

# Allocation must retain a route added since the caller's initial config read.
replace_config("port=10000\nwebsockets_/test/ws-555=first\n".
	"websockets_/test/ws-556=second\n");
my %added;
main::get_miniserv_config(\%added);
is($added{'websockets_/test/ws-556'}, 'second',
	'same-second route addition is visible');

# Cleanup must not restore a route another backend has already removed.
replace_config("port=10000\nwebsockets_/test/ws-556=second\n");
my %removed;
main::get_miniserv_config(\%removed);
ok(!exists($removed{'websockets_/test/ws-555'}),
	'same-second route removal is visible');
is($removed{'websockets_/test/ws-556'}, 'second',
	'unrelated route survives cleanup');
done_testing();
