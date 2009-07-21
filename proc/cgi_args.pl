
do 'proc-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_proc.cgi') {
	return '1';	# First process
	}
elsif ($cgi eq 'open_files.cgi' || $cgi eq 'trace.cgi') {
	return 'pid=1';
	}
elsif ($cgi =~ /^index_/) {
	# All index pages are valid
	return '';
	}
return undef;
}
