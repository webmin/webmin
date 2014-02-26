# tunnel-lib.pl
# Common functions for the HTTP-tunnel module

use strict;
use warnings;
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

1;

