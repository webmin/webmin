#!/usr/bin/perl
# Exercise the real request handler over an isolated Unix socket pair.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use Socket;
BEGIN {
    # Skip this suite if the SQLite Perl drivers are unavailable.
    eval { require DBI; require DBD::SQLite; 1 }
        or plan skip_all => 'DBI and DBD::SQLite are required';
}
require "$FindBin::Bin/../miniserv-lib.pl";
# Serve a protected temporary file, with no host Webmin configuration.
my $dir = tempdir(DIR=>'/tmp', CLEANUP=>1);
open(my $static, '>', "$dir/private.txt") or die $!;
print $static 'fixture-private-content'; close($static);
# SQLite supplies an API-only account through MiniServ's SQL storage path.
my $db = DBI->connect('dbi:SQLite:dbname=:memory:', '', '', {RaiseError=>0,PrintError=>0});
$db->do('create table webmin_user (id integer, name text, pass text)');
$db->do('create table webmin_user_attr (id integer, attr text, value text)');
$db->do('create table webmin_user_acl (id integer, module text, attr text, value text)');
$db->do(q{insert into webmin_user values (1,'fixture','!')});
$db->do(q{insert into webmin_user_acl values (1,'','api_only','virtual-server/remote.cgi')});
# Map a synthetic client IP to the account without password authentication.
%miniserv::config=(env_WEBMIN_CONFIG=>$dir,userdb=>'mysql://fixture',maxconns=>1,
                  agents_nosession=>'Webmin',session=>0);
@miniserv::roots=($dir);
$miniserv::host='test.invalid'; $miniserv::port=10000;
$miniserv::perl_path=$^X;
%miniserv::ipaccess=('192.0.2.42'=>'fixture');
%miniserv::mime=(txt=>'text/plain');
# connect_userdb(url): return the fixture database through the MySQL branch.
*miniserv::connect_userdb=sub { return ($db,'mysql'); };
# disconnect_userdb(url, &db): retain the connection between requests.
*miniserv::disconnect_userdb=sub {};
# log_error(message): suppress expected lookup errors.
*miniserv::log_error=sub {};
# log_request(host, user, request, code, bytes): avoid host access logs.
*miniserv::log_request=sub {};
# write_keep_alive(enabled): omit connection reuse headers from the response.
*miniserv::write_keep_alive=sub {};
# http_error(code, message, [body]): expose unexpected request errors.
*miniserv::http_error=sub { die "HTTP error $_[0]: $_[1]\n"; };
my $response;
# write_data(parts...): capture the HTTP response without a network listener.
*miniserv::write_data=sub { $response.=join('',@_); };
open(*miniserv::DEBUG,'>',\my $debug) or die $!;
for my $broken (0,1) {
    # Compare a valid restricted account with a failed identity query.
    $db->do('drop table webmin_user') if $broken;
    %miniserv::get_user_details_cache=();
    $miniserv::checked_timeout=0; $miniserv::buffer=''; $miniserv::offset=0;
    $response='';
    # Feed a real HTTP request through an isolated Unix socket pair.
    socketpair(*miniserv::SOCK,my $client,AF_UNIX,SOCK_STREAM,PF_UNSPEC) or die $!;
    my $request="GET /private.txt HTTP/1.0\r\nHost: test.invalid\r\nUser-Agent: Fixture\r\n\r\n";
    syswrite($client,$request)==length($request) or die $!;
    eval { miniserv::handle_request('192.0.2.42','192.0.2.1',0); };
    # Neither state may turn this IP mapping into unrestricted static access.
    is($@,'',"request completes with broken=$broken");
    like($response,qr/^HTTP\/1\.0 403/,
        $broken ? 'IP login is denied when the account lookup fails' : 'IP login cannot bypass the stored restriction');
    # A failed lookup must suppress the protected body as well.
    if ($broken) { unlike($response,qr/fixture-private-content/,'protected file content is not returned'); }
    close($client); close(miniserv::SOCK);
}
done_testing();
