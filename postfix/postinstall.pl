require 'postfix-lib.pl';

sub module_install
{
&unlink_logged($version_file);
}
