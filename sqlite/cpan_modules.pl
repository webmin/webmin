require 'sqlite-lib.pl';

# sub cpan_recommended()
# Returns the Perl modules that provide SQLite database access.
sub cpan_recommended
{
return ( "DBI", "DBD::SQLite" );
}
