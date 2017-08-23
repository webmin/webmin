
do 'bind8-lib.pl';

sub list_system_info
{
my ($data, $in) = @_;
my @rv;
my $err = &check_dnssec_client();
if ($err) {
	push(@rv, { 'type' => 'html',
		    'open' => 1,
		    'id' => $module_name.'_dnssec',
		    'priority' => 100,
		    'html' => $err });
	}
return @rv;
}
