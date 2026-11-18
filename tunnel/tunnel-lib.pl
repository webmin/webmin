# tunnel-lib.pl
# Common functions for the HTTP-tunnel module

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

sub fix_end_url {
    my ($url) = @_;
    if ($url =~ m/^(http|https):\/\/(\S+)$/ ) {
        my $schema = $1."://";
        my $host = $2;

        # check: http://aa.com
        # check: http://aa.com/bb.html
        # check: http://aa.com/bb/cc.html
        my $host_test = $2;
        $host_test =~ s/\/?[^\/]*\/*$//;
        if ( $host_test eq '' ) {
            $url = "$schema$host/";
        }
        return $url;
    }
    return 0;
}

# url_allowed(base-url, protocol, host, port, path)
# Returns 1 if a request for the given protocol, host, port and path stays
# within the base URL. The protocol, host and port must match, and the path
# must be under the directory of the base URL path.
sub url_allowed
{
my ($base, $protocol, $host, $port, $path) = @_;
$base =~ /^(http|https):\/\/([^:\/]+)(:(\d+))?(\/.*)?$/i || return 0;
my ($bproto, $bhost, $bport, $bpath) = (lc($1), lc($2), $4, $5 || "/");
$bport ||= $bproto eq "https" ? 443 : 80;
return 0 if ($bproto ne lc($protocol) || $bhost ne lc($host) ||
	     $bport != $port);

# Compare paths without the query string, and refuse paths that the remote
# server could resolve to a parent directory
$bpath =~ s/[?#].*$//;
$bpath =~ s/[^\/]*$//;
my $rpath = $path || "/";
$rpath =~ s/[?#].*$//;
# Check decoded parent segments, but compare the two URL paths as written.
my $decoded = &un_urlize($rpath, 1);
return 0 if ($decoded =~ /\\/ || $decoded =~ m{(?:^|/)\.\.(?:/|$)});
return substr($rpath, 0, length($bpath)) eq $bpath ? 1 : 0;
}

1;

