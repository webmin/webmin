
do 'status-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_mon.cgi') {
	my @serv = &list_services();
	return @serv ? 'id='.&urlize($serv[0]->{'id'}) : 'new=1';
	}
elsif ($cgi eq 'edit_tmpl.cgi') {
	my @tmpls = &list_templates();
	return @tmpls ? 'id='.&urlize($tmpls[0]->{'id'}) : 'new=1';
	}
return undef;
}
