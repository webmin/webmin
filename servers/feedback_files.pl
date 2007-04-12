
do 'servers-lib.pl';

sub feedback_files
{
opendir(DIR, $module_config_directory);
local @rv = map { "$module_config_directory/$_" }
		grep { /\.serv$/ } readdir(DIR);
closedir(DIR);
return @rv;
}

1;

