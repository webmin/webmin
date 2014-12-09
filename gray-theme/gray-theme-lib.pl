# Common functions for theme CGIs

use strict;
use warnings;
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

1;
