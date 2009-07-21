
do 'cron-lib.pl';

sub feedback_files
{
opendir(DIR, $config{'cronfiles_dir'});
local @rv = map { "$config{'cronfiles_dir'}/$_" } grep { !/^\./ } readdir(DIR);
closedir(DIR);
opendir(DIR, $config{'cron_dir'});
push(@rv, map { "$config{'cron_dir'}/$_" } grep { !/^\./ } readdir(DIR));
closedir(DIR);
return @rv;
}

1;

