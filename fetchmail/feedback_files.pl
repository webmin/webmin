
do 'fetchmail-lib.pl';

sub feedback_files
{
if ($config{'config_file'}) {
	return ( $config{'config_file'} );
	}
else {
	local (@rv, @uinfo);
	setpwent();
	while(@uinfo = getpwent()) {
		push(@rv, "$uinfo[7]/.fetchmailrc");
		}
	endpwent();
	return @rv;
	}
}

1;

