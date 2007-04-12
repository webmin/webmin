# change-user-lib.pl

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("acl", "acl-lib.pl");
&foreign_require("webmin", "webmin-lib.pl");
%access = &get_module_acl();

sub can_change_pass
{
return $_[0]->{'pass'} ne 'x' && $_[0]->{'pass'} ne 'e' && !$_[0]{'sync'} &&
       $_[0]->{'pass'} ne "*LK*";
}

