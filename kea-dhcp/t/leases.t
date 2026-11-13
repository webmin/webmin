#!/usr/bin/perl
# Replay real CSV fixtures without starting Webmin or a DHCP server.
use strict;
use warnings;
no warnings qw(once);
use Test::More;
use File::Temp qw(tempdir tempfile);
use FindBin;

our %text = (leases_enofile => 'No file');
my $source = $ENV{'KEA_LEASE_SOURCE'} || "$FindBin::Bin/../kea-dhcp-lib.pl";
open(my $fh, '<', $source) or die "$source: $!";
my $code = do { local $/; <$fh> };
close($fh);
for my $name (qw(kea_read_leases kea_csv_fields
		kea_normalize_lease_field kea_lease_address kea_active_leases
		kea_lease_is_active kea_lease_summary)) {
	$code =~ /^(sub \Q$name\E\n\{\n.*?^\})/ms or die "Missing $name";
	eval $1;
	die $@ if $@;
	}
my $task = tempdir('kea-leases-XXXXXX', DIR => '/tmp', CLEANUP => 1);
my $file;
my @lfc_files;
END { unlink(@lfc_files) if (@lfc_files); }
sub kea_read_dhcp_config { return (undef, { }, undef, undef); }
sub kea_lease_file { return ($file, undef); }
sub text { return join(' ', @_); }
sub read_file_contents {
	open(my $fh, '<', $_[0]) or return undef;
	return do { local $/; <$fh> };
}

# put(suffix, rows...) writes a fresh CSV generation below the fixture root.
sub put
{
my ($suffix, @rows) = @_;
open(my $fh, '>', "$file$suffix") or die $!;
print {$fh} "address,valid_lifetime,expire,state,hostname\n", @rows;
close($fh) or die $!;
}

# row(address, [lifetime, expire, state, hostname]) creates one lease update.
sub row
{
my ($address, $lifetime, $expire, $state, $hostname) = @_;
return join(',', $address, $lifetime // 3600, $expire // 4102444800,
	$state // 0, $hostname // 'client')."\n";
}

# read_rows(version) checks error context and indexes the resulting leases.
sub read_rows
{
my ($ver) = @_;
my ($rows, $err, $path) = kea_read_leases($ver);
is($err, undef, 'lease files are readable');
is($path, $file, 'configured main path is preserved');
return { map { $_->{'address'} => $_ } @$rows };
}

for my $ver (4, 6) {
	my @ip = map { $ver == 4 ? "192.0.2.$_" : "2001:db8::$_" } (10, 2, 3, 4, 5, 1);
	$file = "$task/leases$ver.csv";
	subtest "IPv$ver generations, renewals and deletions" => sub {
		put('.2', map { row($_) } @ip[0..4]);
		put('.1', row($ip[0], 3600, undef, 0, 'renewed'),
			row($ip[1], 0), row($ip[2], 3600, 1), row($ip[3], 3600, undef, 1));
		put('', row($ip[0], 3600, undef, 0, '"last, name"'), row($ip[5]));
		my $rows = read_rows($ver);
		is(scalar(keys %$rows), 5, 'one row per surviving lease');
		is($rows->{$ip[0]}->{'hostname'}, 'last, name', 'latest update wins with quoted CSV');
		ok(!exists($rows->{$ip[1]}), 'zero lifetime deletes an older lease');
		my ($active) = kea_active_leases($ver);
		is_deeply([ map { $_->{'address'} } @$active ],
			[ @ip[0, 4, 5] ], 'active leases retain first-seen order without reviving old leases');
		my $stats = kea_lease_summary($ver);
		is_deeply([ @{$stats}{qw(total active inactive)} ], [ 5, 3, 2 ],
			'counters use current leases, not historical rows');
		};

	subtest "IPv$ver completed cleanup and interrupted recovery" => sub {
		# A completed snapshot supersedes stale inputs, including absent leases.
		put('.completed', row($ip[0], 3600, undef, 0, 'completed'));
		put('.output', row($ip[4], 3600, undef, 0, 'unfinished'));
		put('', row($ip[0], 3600, undef, 0, 'current'), row($ip[5]));
		my $rows = read_rows($ver);
		is_deeply([ sort keys %$rows ], [ sort @ip[0, 5] ],
			'completed replaces inputs and unfinished output is ignored');
		is($rows->{$ip[0]}->{'hostname'}, 'current', 'main file overrides completed snapshot');
		unlink($file) or die $!;
		$rows = read_rows($ver);
		is_deeply([ keys %$rows ], [ $ip[0] ], 'completed works without a main file');
		put('.completed');
		$rows = read_rows($ver);
		is_deeply($rows, { }, 'empty completed snapshot does not revive stale inputs');
		unlink("$file.completed") or die $!;
		unlink("$file.1") or die $!;
		$rows = read_rows($ver);
		is(scalar(keys %$rows), 5, 'previous file alone restores the leases');
		unlink("$file.2") or die $!;
		my ($missing, $err) = kea_read_leases($ver);
		like($err, qr/leases_missing/, 'unfinished output alone reports missing leases');
		};

	subtest "IPv$ver updates within one file and schema changes" => sub {
		put('', row($ip[0]), row($ip[2]), row($ip[0], 0),
			row($ip[0], 3600, undef, 0, 'new'), row($ip[1]), row($ip[1], 0));
		my $rows = read_rows($ver);
		is_deeply([ sort keys %$rows ], [ sort @ip[0, 2] ], 'updates, deletion and reallocation replay in order');
		is($rows->{$ip[0]}->{'hostname'}, 'new', 'last row replaces earlier row in the same file');
		my ($ordered) = kea_read_leases($ver);
		is_deeply([ map { $_->{'address'} } @$ordered ], [ @ip[0, 2] ],
			'reallocated addresses keep their original position without duplicates');
		open(my $fh, '>', "$file.1") or die $!;
		print {$fh} "hostname,address,valid_lifetime,expire\r\nold-schema,$ip[3],3600,4102444800\r\n";
		close($fh);
		$rows = read_rows($ver);
		is($rows->{$ip[3]}->{'hostname'}, 'old-schema', 'each input uses its own header');
		};

	}

# put_kea(version, suffix, &leases) writes the schema accepted by kea-lfc.
sub put_kea
{
my ($ver, $suffix, $leases) = @_;
my @fields = $ver == 4 ? qw(address hwaddr client_id valid_lifetime expire
	subnet_id fqdn_fwd fqdn_rev hostname state user_context pool_id) :
	qw(address duid valid_lifetime expire subnet_id pref_lifetime lease_type
	iaid prefix_len fqdn_fwd fqdn_rev hostname hwaddr state user_context
	hwtype hwaddr_source pool_id);
open(my $fh, '>', "$file$suffix") or die $!;
print {$fh} join(',', @fields)."\n";
foreach my $lease (@$leases) {
	my %row = (hwaddr => '00:11:22:33:44:55', client_id => '',
		duid => '00:01:02:03', valid_lifetime => 3600,
		expire => 4102444800, subnet_id => 1, pref_lifetime => 1800,
		lease_type => 0, iaid => 1, prefix_len => 128, fqdn_fwd => 0,
		fqdn_rev => 0, hostname => 'client', state => 0,
		user_context => '', hwtype => 1, hwaddr_source => 0,
		pool_id => 0, %$lease);
	print {$fh} join(',', @row{@fields})."\n";
	}
close($fh) or die $!;
}

if (($ENV{'KEA_LFC_VM_TEST'} || '') eq '1') {
	# Run the installed cleanup program only on an explicitly selected VM.
	die "Disposable root Linux VM required\n" if ($^O ne 'linux' || $> != 0);
	local $ENV{'KEA_LOCKFILE_DIR'} = 'none';
	for my $ver (4, 6) {
		subtest "IPv$ver real kea-lfc cleanup" => sub {
			# Debian's AppArmor profile permits only Kea's lease filenames.
			my ($fh, $path) = tempfile("kea-leases$ver.csv.webmin-XXXXXX",
				DIR => $ENV{'KEA_LFC_LEASE_DIR'} || $task);
			close($fh);
			$file = $path;
			push(@lfc_files, map { "$file$_" }
				('', '.1', '.2', '.output', '.completed', '.pid'));
			my @ip = map { $ver == 4 ? "192.0.2.$_" : "2001:db8::$_" } 1..3;
			put_kea($ver, '.2', [ map { { address => $_ } } @ip[0, 1] ]);
			put_kea($ver, '.1', [
				{ address => $ip[0], hostname => 'renewed' },
				{ address => $ip[1], valid_lifetime => 0 } ]);
			put_kea($ver, '', [ { address => $ip[2] } ]);
			my $before = read_rows($ver);
			is_deeply([ sort keys %$before ], [ sort @ip[0, 2] ],
				'leases are complete before cleanup');
			is(system('kea-lfc', "-$ver", '-c', 'ignored',
				'-p', "$file.pid", '-x', "$file.2", '-i', "$file.1",
				'-o', "$file.output", '-f', "$file.completed"), 0,
				'Kea cleanup succeeds');
			my $after = read_rows($ver);
			is_deeply([ sort keys %$after ], [ sort keys %$before ],
				'cleanup preserves the displayed lease set');
			is($after->{$ip[0]}->{'hostname'}, 'renewed',
				'latest renewal survives actual compaction');
			ok(!-e "$file.1" && !-e "$file.completed", 'Kea finished rotating its inputs');
			};
		}
	}

done_testing();
