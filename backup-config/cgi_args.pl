
use strict;
use warnings;
do 'backup-config-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit.cgi') {
	my @backups = &list_backups();
	return @backups ? 'id='.&urlize($backups[0]->{'id'})
			: 'new=1';
	}
return undef;
}
