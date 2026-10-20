#!/usr/bin/perl
# Compare MiniServ's tied input reader with Perl read, without a server.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
require "$FindBin::Bin/../miniserv-lib.pl";

my @cases = (
	['short final chunk', 'abcdefghij', '', [[8], [8]]],
	['socket-sized chunks', 'x' x 100000, '', [[65536], [65536]]],
	['EOF clears old data', '', 'old contents', [[8]]],
	['offset preserves prefix', 'xy', 'abcdefgh', [[8, 3]]],
	['offset pads with zeros', 'xy', 'abc', [[8, 5]]],
	['negative offset', 'xy', 'abc', [[8, -1]]],
	['zero length truncates', 'xy', 'abcdef', [[0, 2], [8]]],
	['binary input', "a\0b\xffc", 'old contents', [[3], [3]]],
);

# Both already-buffered POST data and later socket reads reuse the CGI buffer.
for my $source ('buffer', 'socket') {
	for my $case (@cases) {
		my ($label, $input, $initial, $reads) = @$case;
		subtest "$source: $label" => sub {
			local $miniserv::postinput = $source eq 'buffer' ? $input : '';
			local $miniserv::postpos = 0;
			my $stream = $source eq 'socket' ? $input : '';
			my $socket_reads = 0;
			local *miniserv::read_data = sub {
				$socket_reads++;
				return substr($stream, 0, $_[0], '');
				};
			open(my $native, '<', \$input) or die $!;
			my ($expected, $actual) = ($initial, $initial);
			for my $read (@$reads) {
				my ($len, $offset) = @$read;
				my $count = read($native, $expected, $len, $offset // 0);
				my $before = $socket_reads;
				is(miniserv::READ(undef, $actual, $len, $offset), $count,
					'byte count matches read');
				is($actual, $expected, 'buffer matches read');
				is($socket_reads, $before, 'zero-length read does not use socket')
					if (!$len);
				}
			};
		}
	}

# Reading can cross from the buffered request into the socket on the next call.
{
	local $miniserv::postinput = 'abcdefgh';
	local $miniserv::postpos = 0;
	local *miniserv::read_data = sub { return 'ij'; };
	my $buf;
	is(miniserv::READ(undef, $buf, 8), 8, 'buffered prefix read');
	is(miniserv::READ(undef, $buf, 8), 2, 'short socket continuation read');
	is($buf, 'ij', 'socket continuation does not retain the buffered tail');
}
done_testing();
