#!/usr/local/bin/perl
# Save module description overrides

require './usermin-lib.pl';
&ReadParse();
&error_setup($text{'descs_err'});

for($i=0; defined($mod = $in{"mod_$i"}); $i++) {
	$desc = $in{"desc_$i"};
	next if (!$mod);
	%minfo = &get_usermin_module_info($mod);
	$desc =~ /\S/ || &error(&text('descs_edesc', $minfo{'realdesc'}));
	$descs{$mod} = $desc;
	}
&lock_file("$config{'usermin_dir'}/webmin.descs");
&write_file("$config{'usermin_dir'}/webmin.descs", \%descs);
&unlock_file("$config{'usermin_dir'}/webmin.descs");
&flush_modules_cache();
&webmin_log("descs");
&redirect("");

