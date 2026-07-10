#!/usr/bin/perl
# Unit tests for byte-copying helpers in web-lib-funcs.pl.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use bytes ();

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

subtest 'copydata_len to file handle' => sub {
	my $source = "abcdef";
	my $dest = "";
	open(my $in, '<', \$source) or die "open input scalar: $!";
	open(my $out, '>', \$dest) or die "open output scalar: $!";

	is(main::copydata_len($in, $out, 4, 2), 4,
	   'reports copied byte count');
	is($dest, 'abcd', 'copies only the requested bytes');

	my $left = <$in>;
	is($left, 'ef', 'leaves bytes past the requested length unread');
};

subtest 'copydata_len to writer callback' => sub {
	my $source = "0123456789";
	my @chunks;
	open(my $in, '<', \$source) or die "open input scalar: $!";

	is(main::copydata_len($in, sub { push(@chunks, $_[0]); 1 }, 7, 3),
	   7, 'reports bytes copied through callback');
	is(join('', @chunks), '0123456', 'callback receives requested data');
	is_deeply([ map { length($_) } @chunks ], [ 3, 3, 1 ],
		  'callback receives bounded chunks');
};

subtest 'copydata_len short input and write failure' => sub {
	my $short = "abc";
	my $dest = "";
	open(my $in, '<', \$short) or die "open input scalar: $!";
	open(my $out, '>', \$dest) or die "open output scalar: $!";

	is(main::copydata_len($in, $out, 5, 2), 3,
	   'short input returns actual copied byte count');
	is($dest, 'abc', 'short input copies available bytes');

	my $source = "abcdef";
	open(my $fail_in, '<', \$source) or die "open input scalar: $!";
	is(main::copydata_len($fail_in, sub { 0 }, 4, 2), undef,
	   'writer callback failure returns undef');
};

subtest 'write_http_connection retries partial SSL writes' => sub {
	my @writes;
	{
		no warnings 'redefine';
		local *Net::SSLeay::write = sub {
			my ($ssl, $data) = @_;
			push(@writes, $data);
			return length($data) > 2 ? 2 : length($data);
			};

		ok(main::write_http_connection(
			{ ssl_ctx => 1, ssl_con => 'ssl' }, 'abcde'),
		   'partial SSL writes eventually succeed');
		}
	is_deeply(\@writes, [ 'abcde', 'cde', 'e' ],
		  'remaining bytes are retried after each partial write');
};

subtest 'write_http_connection uses byte offsets for UTF-8 strings' => sub {
	my $source = "\x{100}\x{101}\x{102}";
	my @accepted;
	{
		no warnings 'redefine';
		local *Net::SSLeay::write = sub {
			my ($ssl, $data) = @_;
			my $len = bytes::length($data);
			my $wrote = $len > 3 ? 3 : $len;
			push(@accepted,
			     unpack('H*', bytes::substr($data, 0, $wrote)));
			return $wrote;
			};

		ok(main::write_http_connection(
			{ ssl_ctx => 1, ssl_con => 'ssl' }, $source),
		   'partial SSL writes preserve a UTF-8-flagged scalar');
		}
	is(join('', @accepted),
	   unpack('H*', bytes::substr($source, 0, bytes::length($source))),
	   'byte-count return values are applied as byte offsets');
};

subtest 'write_http_connection fails on SSL write error' => sub {
	{
		no warnings 'redefine';
		local *Net::SSLeay::write = sub { return 0; };

		ok(!main::write_http_connection(
			{ ssl_ctx => 1, ssl_con => 'ssl' }, 'abc'),
		   'zero-byte SSL write is reported as failure');
		}
};

done_testing();
