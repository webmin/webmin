#!/usr/bin/perl
# Test uncached API policies and failures when reading account restrictions.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
require "$FindBin::Bin/../miniserv-lib.pl";
my $dir = tempdir(CLEANUP => 1);
$miniserv::config{'env_WEBMIN_CONFIG'} = $dir;
# policy([endpoint]): replace the fixture ACL, or remove it when omitted.
sub policy {
    my ($endpoint) = @_;
    unlink("$dir/integration.acl");
    if (defined($endpoint)) {
        open(my $fh, '>', "$dir/integration.acl") or die $!;
        print $fh "api_only=$endpoint\n";
        close($fh) or die $!;
    }
}
is_deeply([miniserv::get_api_only_endpoint('integration', {})], [undef, undef],
          'ordinary local account has no API policy');
policy('virtual-server/remote.cgi');
is_deeply([miniserv::get_api_only_endpoint('integration', {})],
          ['virtual-server/remote.cgi', undef], 'local policy is enforced');
policy('another/api.cgi');
is_deeply([miniserv::get_api_only_endpoint('integration', {})],
          ['another/api.cgi', undef], 'subsequent requests read changed policy');
policy('');
is_deeply([miniserv::get_api_only_endpoint('integration', {})], ['', undef],
          'explicit clearing takes effect without a cached restriction');
policy();
mkdir("$dir/integration.acl") or die $!;
ok((miniserv::get_api_only_endpoint('integration', {}))[1],
   'invalid policy file is an error, not unrestricted access');
rmdir("$dir/integration.acl");
{
    # A failed database read must never use an unrestricted local policy.
    local *miniserv::connect_userdb = sub { return 'database unavailable'; };
    ok((miniserv::get_api_only_endpoint('integration', {proto => 'postgresql', id => 1}))[1],
       'database outage fails closed');
}
done_testing();
