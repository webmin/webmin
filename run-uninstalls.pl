#!/usr/local/bin/perl
# run-uninstalls.pl
# Run all the uninstall.pl scripts in module directories

use lib '.';
BEGIN { push(@INC, "."); };
$no_acl_check++;
use WebminCore;
&init_config();
@themes = &list_themes();

if (@ARGV > 0) {
	# Running for specified modules
	foreach $a (@ARGV) {
		local %minfo = &get_module_info($a);
		if (!%minfo) {
			# Try for a theme
			($tinfo) = grep { $_->{'dir'} eq $a } @themes;
			if ($tinfo) {
				push(@mods, $tinfo);
				}
			}
		else {
			push(@mods, \%minfo);
			}
		}
	}
else {
	# Running on all modules and themes
	@mods = ( &get_all_module_infos(), @themes );
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
			print STDERR "$m->{'dir'}/uninstall.pl failed : $@\n";
			}
		}
	}

