
do 'majordomo-lib.pl';

sub feedback_files
{
local $conf = &get_config();
local $ldir = &perl_var_replace(&find_value("listdir", $_[0]), $_[0]);
local @lists = &list_lists($conf);
local $aliases = $config{'aliases_file'} ? $config{'aliases_file'}
					 : "/etc/aliases";
return ( $config{'majordomo_cf'}, $aliases, map { "$ldir/$_.config" } @lists );
}

1;

