=head1 change-user-lib.pl

This module has no actual functionality of it's own, so there isn't much to
say here.

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("acl", "acl-lib.pl");
&foreign_require("webmin", "webmin-lib.pl");
%access = &get_module_acl();

=head2 can_change_pass(&user)

Returns 1 if some user's password can be changed.

=cut
sub can_change_pass
{
return $_[0]->{'pass'} ne 'x' && $_[0]->{'pass'} ne 'e' && !$_[0]{'sync'} &&
       $_[0]->{'pass'} ne "*LK*";
}

