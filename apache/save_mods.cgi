#!/usr/local/bin/perl
# Enable or disable Apache modules

require './apache-lib.pl';
&ReadParse();
$access{'global'} == 1 || &error($text{'mods_ecannot'});
&error_setup($text{'mods_err'});

@mods = &list_configured_apache_modules();
%want = map { $_, 1 } split(/\0/, $in{'m'});
$changed = 0;
foreach $m (@mods) {
	if ($want{$m->{'mod'}} && !$m->{'enabled'}) {
		# Need to enable
		&add_configured_apache_module($m->{'mod'});
		$changed++;
		}
	elsif (!$want{$m->{'mod'}} && $m->{'enabled'}) {
		# Need to disable
		&remove_configured_apache_module($m->{'mod'});
		$changed++;
		}
	}

# Force re-detection of modules
unlink($site_file);

# Force restart Apache
if ($changed && &is_apache_running()) {
	$err = &stop_apache();
	&error($err) if ($err);
	&wait_for_apache_stop();
	$err = &start_apache();
	&error($err) if ($err);
	}

&webmin_log("mods");

&redirect("index.cgi?mode=global");


