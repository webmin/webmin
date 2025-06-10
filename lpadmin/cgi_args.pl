
do 'lpadmin-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_printer.cgi') {
	return 'new=1';
	}
elsif ($cgi eq 'list_jobs.cgi') {
	my @plist = grep { &can_edit_jobs($_) } &list_printers();
	return @plist ? 'name='.&urlize($plist[0]->{'name'}) : 'none';
	}
return undef;
}
