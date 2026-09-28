#!/usr/local/bin/perl
# Target of the "apply" link shown at the right of the page title. In a
# real module this is where the configuration would be applied or a
# service restarted, usually followed by a redirect back to the page the
# link was on, given in the redir parameter. This module is read-only, so
# it only redirects.

use strict;
use warnings;

require './ui-demo-lib.pl'; ## no critic
our (%in);

ReadParse();

# Only ever go back to this module's own index page
my $redir = $in{'redir'} || '';
$redir = 'index.cgi' if ($redir !~ /^index\.cgi(\?[\w=&.-]*)?$/);
redirect($redir);
