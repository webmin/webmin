
do 'firewall-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_rule.cgi') {
	my @tables = grep { &can_edit_table($_->{'name'}) }
			  &get_iptables_save();
	if (@tables) {
		my @rules = @{$tables[0]->{'rules'}};
		if (@rules) {
			return 'table='.&urlize($tables[0]->{'name'}).
			       '&idx='.$rules[0]->{'index'};
			}
		return 'table='.&urlize($tables[0]->{'name'}).'&new=1';
		}
	return 'none';
	}
return undef;
}
