
do 'sendmail-lib.pl';
do 'aliases-lib.pl';
do 'virtusers-lib.pl';
do 'mailers-lib.pl';
do 'generics-lib.pl';
do 'domain-lib.pl';
do 'access-lib.pl';

sub feedback_files
{
local $conf = &get_sendmailcf();
local @rv = ( &aliases_file($conf),
	      &virtusers_file($conf),
	      &mailers_file($conf),
	      &generics_file($conf),
	      &domains_file($conf),
	      &access_file($conf) );
}

1;

