
require 'cpan-lib.pl';

# Fix up a bad config
sub module_install
{
if ($config{'packages'} eq '1') {
	# Work around a config bug
	$config{'packages'} = "http://www.cpan.org/modules/02packages.details.txt.gz";
	}
&save_module_config();
}

