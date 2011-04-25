#!/usr/local/bin/perl
# Set OS to automatically detected version

require './webmin-lib.pl';
&ReadParse();

# Do Webmin
&lock_file("$config_directory/config");
%osinfo = &detect_operating_system();
$gconfig{'real_os_type'} = $osinfo{'real_os_type'};
$gconfig{'real_os_version'} = $osinfo{'real_os_version'};
$gconfig{'os_type'} = $osinfo{'os_type'};
$gconfig{'os_version'} = $osinfo{'os_version'};
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

# Do Usermin too, if installed and running an equivalent version
if (&foreign_installed("usermin")) {
	&foreign_require("usermin", "usermin-lib.pl");
	my %miniserv;
	&usermin::get_usermin_miniserv_config(\%miniserv);
	@ust = stat("$miniserv{'root'}/os_list.txt");
	@wst = stat("$root_directory/os_list.txt");
	if ($ust[7] == $wst[7]) {
		# os_list.txt is the same, so we can assume the same OS codes
		# are supported
		&lock_file($usermin::usermin_config);
		&usermin::get_usermin_config(\%uconfig);
		$uconfig{'real_os_type'} = $osinfo{'real_os_type'};
		$uconfig{'real_os_version'} = $osinfo{'real_os_version'};
		$uconfig{'os_type'} = $osinfo{'os_type'};
		$uconfig{'os_version'} = $osinfo{'os_version'};
		&usermin::put_usermin_config(\%uconfig);
		&unlock_file($usermin::usermin_config);
		}
	}

&webmin_log("os");
&redirect($ENV{'HTTP_REFERER'});
