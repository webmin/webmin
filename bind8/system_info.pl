
do 'bind8-lib.pl';

sub list_system_info
{
my ($data, $in) = @_;
my @rv;
if (&foreign_available($module_name) && $access{'defaults'}) {
	my $err = &check_dnssec_client();
	if ($err) {
		push(@rv, { 'type' => 'warning',
			    'level' => 'warn',
			    'warning' => $err });
		}
	}
return @rv;
}
