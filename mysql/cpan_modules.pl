
require 'mysql-lib.pl';

sub cpan_recommended
{
return ( "DBI", $mysql_version =~ /mariadb/i ? "DBD::MariaDB" : "DBD::mysql" );
}
