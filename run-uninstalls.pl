#!/usr/local/bin/perl
# run-uninstalls.pl
# Run all the uninstall.pl scripts in module directories

$no_acl_check++;
use WebminCore;
&init_config();

if (@ARGV > 0) {
	@mods = map { local %minfo = &get_module_info($_); \%minfo } @ARGV;
	}
else {
	@mods = &get_all_module_infos();
	}

foreach $m (@mods) {
	$mdir = &module_root_directory($m->{'dir'});
	if (&check_os_support($m) &&
	    -r "$mdir/uninstall.pl") {
		# Call this module's uninstall function
		eval {
			$main::error_must_die = 1;
			&foreign_require($m->{'dir'}, "uninstall.pl");
			&foreign_call($m->{'dir'}, "module_uninstall");
			};
		if ($@) {
			print STDERR "$m->{'dir'}/postinstall.pl failed : $@\n";
			}
		}
	}

