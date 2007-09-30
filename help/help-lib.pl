# help-lib.pl

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';

sub list_modules
{
local ($m, @rv);
opendir(DIR, "..");
foreach $m (readdir(DIR)) {
	local %minfo;
	if ((%minfo = &get_module_info($m)) && &check_os_support(\%minfo) &&
	    -d "../$m/help") {
		push(@rv, [ $m, \%minfo ]);
		}
	}
closedir(DIR);
return @rv;
}

1;


