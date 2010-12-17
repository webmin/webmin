#!/usr/local/bin/perl
# save_hostsentry.cgi
# Save hostsentry options

require './sentry-lib.pl';
&ReadParse();
&error_setup($text{'hostsentry_err'});

# Validate inputs
-r $in{'wtmp'} || &error($text{'hostsentry_ewtmp'});
@ignore = split(/\s+/, $in{'ignore'});
foreach $u (@ignore) {
	defined(getpwnam($u)) || &error(&text('hostsentry_eignore', $u));
	}
for($i=0; defined($in{"mod_$i"}); $i++) {
	push(@mods, $in{"mod_$i"}) if ($in{"mod_$i"});
	}
if (defined($in{'foreign'})) {
	@foreign = split(/\s+/, $in{'foreign'});
	}
if (defined($in{'multiple'})) {
	@multiple = split(/\s+/, $in{'multiple'});
	foreach $m (@multiple) {
		&to_ipaddress($m) ||
			&error(&text('hostsentry_emultiple', $m));
		}
	}

# Write to the appropriate files
$conf = &get_hostsentry_config();
&lock_config_files($conf);
&save_config($conf, "WTMP_FILE", $in{'wtmp'});
&flush_file_lines();
&unlock_config_files($conf);

$ign = &find_value("IGNORE_FILE", $conf);
&lock_file($ign);
&open_tempfile(IGN, ">$ign");
foreach $i (@ignore) {
	&print_tempfile(IGN, $i,"\n");
	}
&close_tempfile(IGN);
&unlock_file($ign);

$mods = &find_value("MODULE_FILE", $conf);
&lock_file($mods);
&open_tempfile(MODS, ">$mods");
foreach $m (@mods) {
	&print_tempfile(MODS, $m,"\n");
	}
&close_tempfile(MODS);
&unlock_file($mods);

$basedir = &get_hostsentry_dir();
if (length(@foreign)) {
	&lock_file("$basedir/moduleForeignDomain.allow");
	&open_tempfile(FOREIGN, ">$basedir/moduleForeignDomain.allow");
	foreach $f (@foreign) {
		&print_tempfile(FOREIGN, $f,"\n");
		}
	&close_tempfile(FOREIGN);
	&unlock_file("$basedir/moduleForeignDomain.allow");
	}
if (length(@multiple)) {
	&lock_file("$basedir/moduleMultipleLogins.allow");
	&open_tempfile(MULTIPLE, ">$basedir/moduleMultipleLogins.allow");
	foreach $m (@multiple) {
		&print_tempfile(MULTIPLE, $m,"\n");
		}
	&close_tempfile(MULTIPLE);
	&unlock_file("$basedir/moduleMultipleLogins.allow");
	}

if ($in{'apply'}) {
	# Attempt to restart
	&stop_hostsentry();
	$err = &start_hostsentry();
	&error($err) if ($err);
	}
&webmin_log("hostsentry");

&redirect("");

