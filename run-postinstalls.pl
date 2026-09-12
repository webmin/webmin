#!/usr/local/bin/perl
# run-postinstalls.pl
# Run all the postinstall.pl scripts in module and theme directories

use lib '.';
BEGIN { push(@INC, "."); };
$no_acl_check++;
use WebminCore;
&init_config();
$current_theme = $WebminCore::current_theme = undef;

# Pause WebminCron jobs while module post-install scripts run.
# Each runner uses its own marker.
my %miniserv;
&get_miniserv_config(\%miniserv);
# Use the same default path as Miniserv.
my $miniserv_var_dir = $var_directory;
$miniserv_var_dir = $1
	if ($miniserv{'pidfile'} &&
	    $miniserv{'pidfile'} =~ /^(.*)\/[^\/]+$/);
my $webmincron_pause_file = $miniserv{'webmincron_pause'} ||
	$miniserv_var_dir."/webmincron-pause";
my $webmincron_pause_dir = $webmincron_pause_file.".d";
my $webmincron_pause_marker = $webmincron_pause_dir."/".$$;
my $webmincron_pause_pid = $$;
my $webmincron_paused;
if (!-d $webmincron_pause_dir &&
    !mkdir($webmincron_pause_dir, 0700) &&
    !-d $webmincron_pause_dir) {
	print STDERR "Cannot pause scheduled jobs: failed to create " .
		     "$webmincron_pause_dir: $!\n";
	}
elsif (open(my $pause, ">", $webmincron_pause_marker)) {
	close($pause);
	$webmincron_paused = 1;
	}
else {
	print STDERR "Cannot pause scheduled jobs: failed to create " .
		     "$webmincron_pause_marker: $!\n";
	}
# Forked children also run the END block, so only the owner removes its marker.
# Keep the shared directory for concurrent runners.
END {
	if ($webmincron_paused && $$ == $webmincron_pause_pid) {
		unlink($webmincron_pause_marker);
		}
	}

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
