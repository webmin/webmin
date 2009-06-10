
do 'procmail-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @conf = &get_procmailrc();
if ($cgi eq 'edit_recipe.cgi') {
	my ($r) = grep { !$_->{'name'} && !$_->{'include'} } @conf;
	return $r ? 'idx='.$r->{'index'} : 'new=1';
	}
elsif ($cgi eq 'edit_env.cgi') {
	my ($r) = grep { $_->{'name'} } @conf;
	return $r ? 'idx='.$r->{'index'} : 'new=1';
	}
elsif ($cgi eq 'edit_inc.cgi') {
	my ($r) = grep { $_->{'include'} } @conf;
	return $r ? 'idx='.$r->{'index'} : 'new=1';
	}
return undef;
}
