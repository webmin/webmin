
do 'fsdump-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @dumps = grep { &can_edit_dir($_) } &list_dumps();
if ($cgi eq 'edit_dump.cgi') {
	return @dumps ? 'id='.&urlize($dumps[0]->{'id'}) : 'dir=/etc';
	}
elsif ($cgi eq 'restore_form.cgi') {
	return @dumps ? 'id='.&urlize($dumps[0]->{'id'}).
		 	'&fs='.$dumps[0]->{'fs'}
		      : 'fs=tar';
	}
return undef;
}
