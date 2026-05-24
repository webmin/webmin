use strict;
use warnings;
require 'bind8-lib.pl';    ## no critic

sub cpan_recommended
{
return ("Net::DNS::SEC::Tools::dnssectools",
        "Net::DNS::RR::DS",
	      "Net::DNS");
}
