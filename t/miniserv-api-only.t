#!/usr/bin/perl
# Check API-only restrictions on WebSockets, DAV and CGI execution.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use Socket;
require "$FindBin::Bin/../miniserv-lib.pl";
my $dir = tempdir(TMPDIR => 1, CLEANUP => 1);

# write_acl(user, content): create a global ACL in the temporary configuration.
sub write_acl
{
my ($user, $content) = @_;
open(my $fh, '>', "$dir/$user.acl") or die $!;
print $fh $content;
close($fh) or die $!;
}

# request(base-user, [user-details], [login-name], [webmin])
# Run the real WebSocket handler, stopping when it tries to open the backend.
# Defaults to a local Webmin account whose login name matches base-user.
# Set webmin to 0 to test standalone MiniServ.
sub request
{
my ($base, $details, $login, $webmin) = @_;
my ($status, $backend, $direct) = (undef, 0, 0);
# Set up account identity without loading the host's Webmin configuration.
local %miniserv::config = (env_WEBMIN_CONFIG => $dir, userdb => 'mysql://fixture');
delete($miniserv::config{env_WEBMIN_CONFIG}) if defined($webmin) && !$webmin;
local $miniserv::authuser = $login || $base;
local $miniserv::baseauthuser = $base;
local $miniserv::uinfo = $details || {name => $base};
# Supply valid WebSocket headers and stop before opening a network connection.
local %miniserv::header = (
    'sec-websocket-key' => 'dGhlIHNhbXBsZSBub25jZQ==',
    origin => 'http://test.invalid');
local *miniserv::get_websocket_allowed_origins = sub { return 'http://test.invalid'; };
local *miniserv::open_socket = sub { $backend++; die "BACKEND\n"; };
# http_error(code, message): record whether a denial skips the custom error CGI.
local *miniserv::http_error = sub {
    $status = $_[0];
    $direct = $miniserv::error_handler_recurse;
    die "DENIED\n";
    };
# Ignore expected stops and report any unexpected error.
eval { miniserv::handle_websocket_request({host => 'backend.invalid', port => 80}, '/socket'); };
die $@ if $@ && $@ ne "BACKEND\n" && $@ ne "DENIED\n";
return [$status, $backend, $direct ? 1 : 0];
}

# Restrictions follow the base account; ordinary accounts keep WebSocket access.
write_acl('api', "api_only=virtual-server/remote.cgi\n");
is_deeply(request('api'), [403, 0, 1], 'restricted account denied without backend or custom error CGI');
is_deeply(request('api', undef, 'mapped'), [403, 0, 1], 'mapped login uses the base account policy');
is_deeply(request('ordinary'), [undef, 1, 0], 'missing ACL allows an ordinary account');
write_acl('ordinary', "rpc=1\n");
is_deeply(request('ordinary'), [undef, 1, 0], 'ordinary global permissions still allow WebSockets');
# Policy changes take effect on the next request without a server reload.
write_acl('ordinary', "api_only=virtual-server/remote.cgi\n");
is_deeply(request('ordinary'), [403, 0, 1], 'new restriction is read without reloading MiniServ');
write_acl('ordinary', "rpc=1\n");
is_deeply(request('ordinary'), [undef, 1, 0], 'removed restriction does not remain cached');
# Use a directory to test an invalid ACL file even when running as root.
mkdir("$dir/unreadable.acl") or die $!;
is_deeply(request('unreadable'), [403, 0, 1], 'unreadable policy does not allow a connection');
is_deeply(request('api', undef, undef, 0), [undef, 1, 0], 'non-Webmin MiniServ behavior is unchanged');

# Use SQLite to exercise the query shared by the MySQL and PostgreSQL branches.
SKIP: {
    eval { require DBI; require DBD::SQLite; 1 } or skip 'DBD::SQLite required', 6;
    my $db = DBI->connect('dbi:SQLite:dbname=:memory:', '', '',
                         {RaiseError => 0, PrintError => 0});
    $db->do('create table webmin_user_acl (id integer, module text, attr text, value text)');
    $db->do("insert into webmin_user_acl values (1, '', 'api_only', 'virtual-server/remote.cgi')");
    local *miniserv::disconnect_userdb = sub {};
    foreach my $proto ('mysql', 'postgresql') {
        local *miniserv::connect_userdb = sub { return ($db, $proto); };
        is_deeply(request('database', {proto => $proto, id => 1}), [403, 0, 1],
                  "$proto restriction comes from the database");
        is_deeply(request('database', {proto => $proto, id => 2}), [undef, 1, 0],
                  "$proto ordinary account is allowed");
    }
    # Failed queries and connections must not fall back to unrestricted access.
    $db->do('drop table webmin_user_acl');
    local *miniserv::connect_userdb = sub { return ($db, 'mysql'); };
    is_deeply(request('database', {proto => 'mysql', id => 1}), [403, 0, 1],
              'failed ACL query denies the connection');
    local *miniserv::connect_userdb = sub { return 'Database unavailable'; };
    is_deeply(request('database', {proto => 'mysql', id => 1}), [403, 0, 1],
              'database connection failure does not fall back to a local ACL');
}

# LDAP exposes the same restriction as an attribute of the global ACL entry.
{
    package FixtureLDAP;
    # search(arguments): return the configured LDAP result for the global ACL.
    sub search { return $_[0]; }
    # code(): expose an LDAP search failure when requested by the fixture.
    sub code { return $_[0]->{error}; }
    # all_entries(): return an ACL entry only when one exists.
    sub all_entries { return $_[0]->{present} ? ($_[0]) : (); }
    # get_value(attribute): return the ACL's stored name=value entries.
    sub get_value { return @{$_[0]->{values}}; }
}
{
    my $ldap = bless { present => 1, values => ['api_only=virtual-server/remote.cgi'] }, 'FixtureLDAP';
    local *miniserv::connect_userdb = sub { return ($ldap, 'ldap'); };
    local *miniserv::disconnect_userdb = sub {};
    my $user = {proto => 'ldap', id => 'cn=api,dc=test'};
    is_deeply(request('database', $user), [403, 0, 1], 'LDAP API account is denied');
    $ldap->{values} = ['rpc=1'];
    is_deeply(request('database', $user), [undef, 1, 0], 'ordinary LDAP account is allowed');
    $ldap->{present} = 0;
    is_deeply(request('database', $user), [undef, 1, 0], 'missing LDAP ACL is unrestricted');
    $ldap->{error} = 1;
    is_deeply(request('database', $user), [403, 0, 1], 'LDAP lookup failure denies access');
}
# These CGI fixtures omit Webmin initialization, including its API-only check.
mkdir("$dir/allowed") or die $!;
foreach my $name ('custom.cgi', 'allowed/remote.cgi', 'error.cgi') {
	open(my $fh, '>', "$dir/$name") or die $!;
	print $fh "#!$^X\nprint qq(Content-type: text/plain\\r\\n\\r\\nCGI_RAN);\n";
	close($fh) or die $!;
	chmod(0700, "$dir/$name") or die $!;
	}
# Static files remain accessible to API-only accounts.
open(my $asset, '>', "$dir/asset.txt") or die $!;
print $asset 'STATIC_BODY';
close($asset) or die $!;
write_acl('api', "api_only=allowed/remote.cgi\n");

# http_request(user, path): dispatch without a TCP listener or host config.
sub http_request
{
my ($user, $path) = @_;
my ($status, $direct, $body) = (undef, 0, '');
# Authenticate a fixture account by IP and resolve paths under the temporary root.
local %miniserv::config = (env_WEBMIN_CONFIG => $dir, maxconns => 1,
	agents_nosession => 'Webmin', session => 0, forkcgis => 1,
	index_docs => 'remote.cgi', error_handler_403 => 'error.cgi');
local @miniserv::roots = ($dir);
local @miniserv::davpaths = ('/dav');
local %miniserv::users = (api => '!', ordinary => '!', unreadable => '!');
local %miniserv::ipaccess = ('192.0.2.42' => $user);
local %miniserv::mime = (cgi => 'internal/cgi');
local $miniserv::host = 'test.invalid';
local $miniserv::port = 10000;
local $miniserv::perl_path = $^X;
# Reset request state so one call cannot supply buffered data to the next.
local $miniserv::checked_timeout = 0;
local $miniserv::buffer = '';
local $miniserv::offset = 0;
local $miniserv::cgipid;
# Capture the response and status without writing logs or socket output.
local *miniserv::log_error = sub {};
local *miniserv::log_request = sub { $status = $_[3]; };
local *miniserv::write_keep_alive = sub {};
local *miniserv::write_data = sub { $body .= join('', @_); };
# http_error(code, message): record denials and the custom error handler flag.
local *miniserv::http_error = sub {
	$status = $_[0];
	$direct = $miniserv::error_handler_recurse ? 1 : 0;
	die "DENIED\n";
	};
# Feed a real HTTP request through a Unix socket pair without a TCP listener.
local *miniserv::DEBUG;
open(miniserv::DEBUG, '>', \my $debug) or die $!;
socketpair(*miniserv::SOCK, my $client, AF_UNIX, SOCK_STREAM, PF_UNSPEC) ||
	die $!;
my $request = "GET $path HTTP/1.0\r\nHost: test.invalid\r\n".
	"User-Agent: Webmin test\r\n\r\n";
syswrite($client, $request) == length($request) or die $!;
eval { miniserv::handle_request('192.0.2.42', '192.0.2.1', 0); };
my $err = $@;
# Close both sockets and reap any forked CGI before checking the result.
close($client);
close(miniserv::SOCK);
waitpid($miniserv::cgipid, 0) if ($miniserv::cgipid);
die $err if ($err && $err ne "DENIED\n");
return [$status, $body =~ /CGI_RAN|STATIC_BODY/ ? 1 : 0, $direct];
}

# Enforce before custom code runs, including PATH_INFO and directory indexes.
is_deeply(http_request('api', '/custom.cgi'), [403, 0, 1],
	'custom CGI is denied without running a custom error page');
is_deeply(http_request('api', '/custom.cgi/extra'), [403, 0, 1],
	'custom CGI with PATH_INFO is denied');
is_deeply(http_request('ordinary', '/custom.cgi'), [200, 1, 0],
	'ordinary account can still run a custom CGI');
foreach my $path ('/allowed/remote.cgi?x=1', '/allowed/remote.cgi/extra',
		 '/allowed/', '/allowed//remote.cgi') {
	is_deeply(http_request('api', $path), [200, 1, 0],
		"assigned CGI is allowed at $path");
	}
# DAV is blocked, static files stay accessible, and failed ACL reads deny CGI.
is_deeply(http_request('api', '/dav/file'), [403, 0, 1],
	'DAV is denied before its modules or filesystem are used');
is_deeply(http_request('api', '/asset.txt'), [200, 1, 0],
	'static files remain accessible');
is_deeply(http_request('unreadable', '/allowed/remote.cgi'), [403, 0, 1],
	'failed policy read denies CGI execution');
done_testing();
