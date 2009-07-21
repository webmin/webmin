
do 'status-lib.pl';

sub feedback_files
{
opendir(DIR, $services_dir);
local @rv = map { "$services_dir/$_" } grep { !/^\./ } readdir(DIR);
closedir(DIR);
return @rv;
}

1;

