
do 'tcpwrappers-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_rule.cgi') {
	my @rules = &list_rules($config{'hosts_allow'});
	my $type = 'allow';
	if (!@rules) {
		@rules = &list_rules($config{'hosts_deny'});
		$type = 'deny';
		}
	return @rules ? 'edit_rule.cgi?'.$type.'=1'.
			'&id='.$rules[0]->{'id'} : 'new=1&allow=1';
	}
return undef;
}
