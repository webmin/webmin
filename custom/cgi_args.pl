
do 'custom-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @cust = grep { &can_run_command($_) } &list_commands();
if ($cgi eq 'edit_cmd.cgi') {
	# Custom command editor
	my ($cmd) = grep { !$_->{'edit'} && !$_->{'sql'} } @cust;
	return $cmd ? 'id='.&urlize($cmd->{'id'}) :
	       $access{'edit'} ? 'new=1' : 'none';
	}
elsif ($cgi eq 'form.cgi') {
	# Custom command form
	my ($cmd) = grep { !$_->{'edit'} && !$_->{'sql'} } @cust;
	return $cmd ? 'id='.&urlize($cmd->{'id'}) : 'none';
	}
elsif ($cgi eq 'edit_file.cgi') {
	# File editor editor
	my ($cmd) = grep { $_->{'edit'} } @cust;
	return $cmd ? 'id='.&urlize($cmd->{'id'}) :
	       $access{'edit'} ? 'new=1' : 'none';
	}
elsif ($cgi eq 'view.cgi') {
	# Custom command form
	my ($cmd) = grep { $_->{'edit'} } @cust;
	return $cmd ? 'id='.&urlize($cmd->{'id'}) : 'none';
	}
elsif ($cgi eq 'edit_sql.cgi') {
	# SQL query
	my ($cmd) = grep { $_->{'sql'} } @cust;
	return $cmd ? 'id='.&urlize($cmd->{'id'}) :
	       $access{'edit'} ? 'new=1' : 'none';
	}
elsif ($cgi eq 'sqlform.cgi') {
	# SQL query form
	my ($cmd) = grep { $_->{'sql'} } @cust;
	return $cmd ? 'id='.&urlize($cmd->{'id'}) : 'none';
	}
return undef;
}
