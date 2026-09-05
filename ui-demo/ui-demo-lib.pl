=head1 ui-demo-lib.pl

Common functions for the UI demo module. The page builders live in
ui-demo-pages.pl, which uses WebminCore helpers and the page's language,
configuration and input hashes. The builders can also be rendered with
standalone test data without calling init_config.

=cut

use strict;
use warnings;
use lib "..";

use WebminCore;

our (%access, %config, %gconfig, %in, %text);

# This is a read-only reference module with nothing to protect, so it is
# usable without being listed in any user's module ACL. That way it
# works as soon as it is dropped into the Webmin root, without going
# through the module installer.
$main::no_acl_check = 1;

init_config();

do './ui-demo-pages.pl';

1;
