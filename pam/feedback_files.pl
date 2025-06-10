
do 'pam-lib.pl';

sub feedback_files
{
opendir(DIR, $config{'pam_dir'});
local @rv = map { "$config{'pam_dir'}/$_" } grep { !/^\./ } readdir(DIR);
closedir(DIR);
return @rv;
}

1;

