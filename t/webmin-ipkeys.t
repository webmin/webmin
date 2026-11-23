#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;

open(my $lib, '<', "$FindBin::Bin/../webmin/webmin-lib.pl") or die $!;
my $source = do { local $/; <$lib> };
for my $sub (qw(get_ipkeys find_ipkey save_ipkeys)) {
	$source =~ /(^sub \Q$sub\E\n\{.*?^\})/ms or die "missing $sub";
	eval $1;
	die $@ if $@;
	}
my %conf = ('ipkey_a.test' => 'a.key', 'ipkey_b.test,*.b.test' => 'b.key');
my @keys = get_ipkeys(\%conf);
is($keys[0]->{'key'}, 'a.key', 'stable list order');
my $id = join(',', @{$keys[1]->{'ips'}});
$conf{'ipkey_aaa.test'} = 'new.key';
@keys = get_ipkeys(\%conf);
my $selected = find_ipkey(\@keys, $id);
is($selected->{'key'}, 'b.key', 'another mapping inserted while editing');
splice(@keys, $selected->{'index'}, 1);
save_ipkeys(\%conf, \@keys);
is_deeply(\%conf, { 'ipkey_a.test' => 'a.key', 'ipkey_aaa.test' => 'new.key' },
	  'deletion preserves both other keys');
ok(!find_ipkey(\@keys, $id), 'a stale mapping cannot select another key');
ok(!find_ipkey(\@keys, undef), 'a missing mapping selects nothing');
done_testing();
