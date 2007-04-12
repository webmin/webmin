#!/usr/local/bin/perl
# Save module description overrides

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'descs_err'});

for($i=0; defined($mod = $in{"mod_$i"}); $i++) {
	$desc = $in{"desc_$i"};
	next if (!$mod);
	%minfo = &get_module_info($mod);
	$desc =~ /\S/ || &error(&text('descs_edesc', $minfo{'realdesc'}));
	$descs{$mod} = $desc;
	}
&lock_file("$config_directory/webmin.descs");
&write_file("$config_directory/webmin.descs", \%descs);
&unlock_file("$config_directory/webmin.descs");
&flush_webmin_caches();
&webmin_log("descs");
&redirect("");

