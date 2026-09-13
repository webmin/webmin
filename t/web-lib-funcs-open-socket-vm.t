#!/usr/bin/perl
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use JSON::PP qw(decode_json);
use Symbol qw(gensym);
use POSIX qw(WNOHANG);

plan skip_all => 'Set WEBMIN_OPEN_SOCKET_VM_TEST=1 on a disposable Linux VM'
    unless ($ENV{'WEBMIN_OPEN_SOCKET_VM_TEST'} || '') eq '1';
$^O eq 'linux' && $< == 0 or die 'Disposable root Linux VM required';
my $source = $ENV{'WEBMIN_OPEN_SOCKET_SOURCE'} ||
    "$FindBin::Bin/../web-lib-funcs.pl";
my $task = tempdir('socket-compat-XXXXXX', DIR => '/tmp', CLEANUP => 1);
note("Fixture directory: $task");
my $server_pid;
END {
    if ($server_pid) {
        kill('TERM', $server_pid);
        waitpid($server_pid, 0);
    }
}
$server_pid = fork();
defined($server_pid) or die $!;
if (!$server_pid) {
    open(STDOUT, '>', "$task/server.log") or die $!;
    open(STDERR, '>&', STDOUT) or die $!;
    exec('python3', "$FindBin::Bin/fixtures/open-socket-server.py", $task);
    die $!;
}
for (1..100) {
    last if -s "$task/ports.json";
    my $exited = waitpid($server_pid, WNOHANG);
    if ($exited == $server_pid) {
        $server_pid = undef;
        die "Fixture server exited: see $task/server.log";
    }
    select(undef, undef, undef, 0.1);
}
open(my $ports_file, '<', "$task/ports.json") or die $!;
my $ports = decode_json(do { local $/; <$ports_file> });
close($ports_file);

$ENV{'WEBMIN_CONFIG'} = '/etc/webmin';
$ENV{'WEBMIN_VAR'} = '/var/webmin';
open(my $mc, '<', '/etc/webmin/miniserv.conf') or die $!;
my ($root) = map { /^root=(.*)/ ? $1 : () } <$mc>;
close($mc);
chdir("$root/webmin") or die $!;
$0 = "$root/webmin/socket-compat-test.pl";
unshift(@INC, $root);
require WebminCore;
WebminCore->import();
init_config();
$main::error_must_die = 1;

# Substitute only the exact original or staged function; use installed callers.
open(my $source_file, '<', $source) or die $!;
my $code = do { local $/; <$source_file> };
close($source_file);
$code =~ /\n(sub open_socket\n\{.*?\n\})\n\n=head2 download_timeout/s or die 'Cannot extract open_socket';
eval "package WebminCore; no strict; no warnings 'redefine'; $1";
die $@ if $@;
*main::open_socket = \&WebminCore::open_socket;

# Limit fixture DNS to loopback while preserving the real literal-IP handling.
my $original4 = \&WebminCore::to_ipaddress;
my $original6 = \&WebminCore::to_ip6address;
my %addresses = (
    'four.invalid' => [['127.0.0.1'], []],
    'six.invalid' => [[], ['::1']],
    'dual.invalid' => [['127.0.0.1'], ['::1']],
    'multiple.invalid' => [['127.0.0.2', '127.0.0.1'], ['::1']],
    'missing.invalid' => [[], []],
);
*WebminCore::to_ipaddress = sub {
    return $original4->(@_) unless exists $addresses{$_[0]};
    my @result = @{$addresses{$_[0]}->[0]};
    return wantarray ? @result : $result[0];
};
*WebminCore::to_ip6address = sub {
    return $original6->(@_) unless exists $addresses{$_[0]};
    my @result = @{$addresses{$_[0]}->[1]};
    return wantarray ? @result : $result[0];
};
# No configured proxy credentials or unrelated HTTP cache writes enter the fixtures.
local @WebminCore::gconfig{qw(http_proxy ftp_proxy proxy_user proxy_pass proxy_fallback bind_proxy)};
local *WebminCore::write_to_http_cache = sub {};
local *WebminCore::no_proxy = sub { 0 };

sub download
{
    my ($host, $port, $ssl, $post) = @_;
    my ($body, $error);
    if (defined $post) {
        http_post($host, $port, '/marker', $post, \$body, \$error,
            undef, $ssl, undef, undef, 5, 0, 1);
    }
    else {
        http_download($host, $port, '/marker', \$body, \$error,
            undef, $ssl, undef, undef, 5, 0, 1);
    }
    is($error, undef, 'request succeeds');
    my $result = eval { decode_json($body || '') };
    ok($result, 'server returned the fixture response') or diag($body || '(empty)');
    return $result || {};
}

for my $case (
    ['HTTP IPv4 literal', '127.0.0.1', 'http4', 0],
    ['HTTP IPv6 literal', '::1', 'http6', 0],
    ['HTTP IPv4 hostname', 'four.invalid', 'http4', 0],
    ['HTTP IPv6-only hostname', 'six.invalid', 'http6', 0],
    ['HTTP dual-stack IPv4 preference', 'dual.invalid', 'http4', 0],
    ['HTTP second IPv4 address', 'multiple.invalid', 'http4', 0],
    ['HTTP IPv6 fallback', 'dual.invalid', 'http6', 0],
    ['HTTPS IPv4', 'four.invalid', 'https4', 1],
    ['HTTPS IPv6', 'six.invalid', 'https6', 1],
    ['HTTPS IPv6 fallback', 'dual.invalid', 'https6', 1],
) {
    subtest $case->[0] => sub {
        my (undef, $host, $port, $ssl) = @$case;
        my $reply = download($host, $ports->{$port}, $ssl);
        is($reply->{'host'}, $host, 'HTTP Host is unchanged');
        is($reply->{'request'}, 'GET /marker HTTP/1.0', 'request reaches the endpoint');
        is($reply->{'sni'}, $host, 'TLS SNI is unchanged') if $ssl;
    };
}

subtest 'POST request body' => sub {
    my $reply = download('four.invalid', $ports->{'https4'}, 1, 'fixture=marker');
    is($reply->{'posted'}, 'fixture=marker', 'HTTPS POST body is preserved');
};

for my $family (4, 6) {
    for my $ssl (0, 1) {
        subtest "HTTP proxy over IPv$family with TLS=$ssl" => sub {
            local $WebminCore::gconfig{'http_proxy'} = "http://dual.invalid:$ports->{'proxy'.$family}";
            my $reply = download('origin.invalid', 8443, $ssl);
            is($reply->{'host'}, 'origin.invalid', 'origin HTTP Host is preserved');
            is($reply->{'request'}, $ssl ? 'GET /marker HTTP/1.0' :
                'GET http://origin.invalid:8443/marker HTTP/1.0', 'proxy request format is preserved');
            if ($ssl) {
                is($reply->{'tunnel'}, 'CONNECT origin.invalid:8443 HTTP/1.0', 'CONNECT negotiation succeeds');
                is($reply->{'sni'}, 'origin.invalid', 'TLS uses the origin hostname');
            }
        };
    }
}

subtest 'HTTP proxy failure with direct fallback' => sub {
    local $WebminCore::gconfig{'http_proxy'} = "http://four.invalid:$ports->{'refused'}";
    local $WebminCore::gconfig{'proxy_fallback'} = 1;
    my $reply = download('four.invalid', $ports->{'http4'}, 0);
    is($reply->{'request'}, 'GET /marker HTTP/1.0', 'falls back to a direct request');
};
subtest 'HTTP proxy failure without fallback' => sub {
    local $WebminCore::gconfig{'http_proxy'} = "http://four.invalid:$ports->{'refused'}";
    my ($body, $error);
    http_download('four.invalid', $ports->{'http4'}, '/', \$body, \$error,
        undef, 0, undef, undef, 5, 0, 1);
    like($error, qr/^Failed to connect to four\.invalid:/, 'proxy connection failure reaches the caller');
};

subtest 'Configured outgoing IPv4 address' => sub {
    local $WebminCore::gconfig{'bind_proxy'} = '127.0.0.2';
    my $reply = download('four.invalid', $ports->{'http4'}, 0);
    is($reply->{'peer'}, '127.0.0.2', 'configured source address is used');
};
subtest 'Explicit outgoing IPv4 address' => sub {
    local $WebminCore::gconfig{'bind_proxy'} = '127.0.0.2';
    my $handle = make_http_connection('four.invalid', $ports->{'http4'}, 0,
        'GET', '/marker', [['Host', 'four.invalid']], '127.0.0.3');
    ok(ref($handle), 'connection succeeds with explicit bind address');
    my ($body, $error);
    complete_http_download($handle, \$body, \$error, undef, undef,
        'four.invalid', $ports->{'http4'}, undef, 0, 1, 5);
    is($error, undef, 'response succeeds');
    is(decode_json($body)->{'peer'}, '127.0.0.3', 'explicit source address takes precedence');
};

for my $case (
    ['DNS failure', 'missing.invalid', qr/Failed to lookup IP address/],
    ['Connection refusal', 'four.invalid', qr/Failed to connect to four\.invalid:/],
) {
    subtest $case->[0] => sub {
        my $fh = gensym();
        my $error;
        is(open_socket($case->[1], $ports->{'refused'}, $fh, \$error), undef, 'returns failure');
        like($error, $case->[2], 'returns the expected error');
        close($fh) if defined(fileno($fh));
    };
}
subtest 'Unavailable source address' => sub {
    local $WebminCore::gconfig{'bind_proxy'} = '192.0.2.123';
    my $fh = gensym();
    my $error;
    is(open_socket('four.invalid', $ports->{'http4'}, $fh, \$error), undef, 'bind failure is reported');
    like($error, qr/^Failed to bind to source address :/, 'bind error is preserved');
    close($fh) if defined(fileno($fh));
};
subtest 'Error without a reference' => sub {
    my $fh = gensym();
    eval { open_socket('missing.invalid', 443, $fh) };
    like($@, qr/Failed to lookup IP address/, 'throws for callers without an error reference');
};

{
    package FixtureCaller;
    sub greeting {
        my ($port) = @_;
        my $error;
        WebminCore::open_socket('127.0.0.1', $port, 'GREETING', \$error);
        die $error if $error;
        my $line = <GREETING>;
        close(GREETING);
        return $line;
    }
}
is(FixtureCaller::greeting($ports->{'greeting'}), "220 loopback fixture ready\r\n",
    'a named handle in another package can read a service greeting');

for my $family (4, 6) {
    subtest "Passive FTP over IPv$family" => sub {
        my $file = "$task/ftp-$family.txt";
        my $error;
        my $host = $family == 4 ? 'four.invalid' : 'six.invalid';
        my $result = ftp_download($host, '/marker.txt', $file, \$error, undef,
            'fixture', 'fixture', $ports->{'ftp'.$family}, 1, 5);
        is($error, undef, 'FTP download has no error');
        ok($result, 'FTP reports success');
        open(my $fh, '<', $file) or die $!;
        is(do { local $/; <$fh> }, "passive FTP marker\n", 'control and data connections work');
        close($fh);
    };
}
done_testing();
