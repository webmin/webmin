use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our %access;

do 'at-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_job.cgi') {
	my @jobs = &list_atjobs();
	@jobs = grep { &can_edit_user(\%access, $_->{'user'}) } @jobs;
	return @jobs ? 'id='.$jobs[0]->{'idx'} : 'none';
	}
return undef;
}
