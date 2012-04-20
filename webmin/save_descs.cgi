#!/usr/local/bin/perl
# Save module description overrides

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'descs_err'});

# Save read module overrides
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

# Save clone overrides
for($i=0; defined($clone = $in{"clone_$i"}); $i++) {
	$title = $in{"title_$i"};
	$title =~ /\S/ || &error(&text('descs_etitle', $clone));
	local %cinfo;
	&lock_file("$config_directory/$clone/clone");
	&read_file("$config_directory/$clone/clone", \%cinfo);
	$cinfo{'desc'} = $title;
	&write_file("$config_directory/$clone/clone", \%cinfo);
	&unlock_file("$config_directory/$clone/clone");
	}

&flush_webmin_caches();
&webmin_log("descs");
&redirect("");

