
use strict;
use warnings;
do 'exports-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_export.cgi') {
	my @exps = &list_exports();
	return @exps ? 'idx='.$exps[0]->{'index'} : 'new=1';
	}
return undef;
}
