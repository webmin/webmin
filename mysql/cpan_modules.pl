
require 'mysql-lib.pl';

sub cpan_recommended
{
return ( "DBI", $mysql_version =~ /mariadb/ ? "DBD::MariaDB" : "DBD::mysql" );
}

