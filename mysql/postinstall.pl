
require 'mysql-lib.pl';

sub module_install
{
my $mysql_version = &get_mysql_version();
if ($mysql_version && $mysql_version >= 0) {
	&save_mysql_version($mysql_version);
	&create_module_info_overrides();
	}
}
