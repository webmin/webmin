# Functions for FreeBSD disk management
#
# XXX call from mount module
# XXX include in makedist.pl
# XXX exclude from Solaris, RPM, Deb

use strict;
use warnings;
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("mount");

1;
