#!/usr/local/bin/perl
# run-postinstalls.pl
# Run all the postinstall.pl scripts in module and theme directories

use lib '.';
BEGIN { push(@INC, "."); };
$no_acl_check++;
use WebminCore;
&init_config();
$current_theme = $WebminCore::current_theme = undef;

if (@ARGV > 0) {
	# Running for specified modules
	foreach my $a (@ARGV) {
		my %minfo = &get_module_info($a);
		%minfo = &get_theme_info($a) if (!%minfo);
		push(@mods, \%minfo) if (%minfo);
		}
	}
else {
	# Running on all modules and themes
	@mods = ( &get_all_module_infos(), &list_themes() );
	}

foreach my $m (@mods) {
	my $mdir = &module_root_directory($m->{'dir'});
	if (&check_os_support($m) &&
	    -r "$mdir/postinstall.pl") {
		# Call this module's postinstall function
		eval {
			local $main::error_must_die = 1;
			&foreign_require($m->{'dir'}, "postinstall.pl");
			&foreign_call($m->{'dir'}, "module_install");
			};
		if ($@) {
			print STDERR "$m->{'dir'}/postinstall.pl failed : $@\n";
			}
		}
	}

