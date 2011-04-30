=head1 change-user-lib.pl

This module has no actual functionality of it's own, so there isn't much to
say here.

=cut

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
&foreign_require("acl", "acl-lib.pl");
&foreign_require("webmin", "webmin-lib.pl");
our %access = &get_module_acl();

=head2 can_change_pass(&user)

Returns 1 if some user's password can be changed.

=cut
sub can_change_pass
{
my ($user) = @_;
return $user->{'pass'} ne 'x' && $user->{'pass'} ne 'e' && !$user->{'sync'} &&
       $user->{'pass'} ne "*LK*";
}

