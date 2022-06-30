# Common functions for theme CGIs

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

1;
