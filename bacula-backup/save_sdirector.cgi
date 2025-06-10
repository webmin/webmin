#!/usr/local/bin/perl
# Create, update or delete a storage daemon director

require './bacula-backup-lib.pl';
&ReadParse();

$conf = &get_storage_config();
$parent = &get_storage_config_parent();
@sdirectors = &find("Director", $conf);

if (!$in{'new'}) {
	$sdirector = &find_by("Name", $in{'old'}, \@sdirectors);
        $sdirector || &error($text{'sdirector_egone'});
	}
else {
	$sdirector = { 'type' => 1,
		     'name' => 'Director',
		     'members' => [ ] };
	}

&lock_file($parent->{'file'});
if ($in{'delete'}) {
	# Just delete this one
	$name = &find_value("Name", $sdirector->{'members'});
	&save_directive($conf, $parent, $sdirector, undef, 0);
	}
else {
	# Validate and store inputs
	&error_setup($text{'sdirector_err'});
	$in{'name'} =~ /\S/ || &error($text{'sdirector_ename'});
	if ($in{'new'} || $in{'name'} ne $in{'old'}) {
		$clash = &find_by("Name", $in{'name'}, \@sdirectors);
		$clash && &error($text{'sdirector_eclash'});
		}
	&save_directive($conf, $sdirector, "Name", $in{'name'}, 1);

	$in{'pass'} || &error($text{'sdirector_epass'});
	&save_directive($conf, $sdirector, "Password", $in{'pass'}, 1);

	&save_directive($conf, $sdirector, "Monitor",
			$in{'monitor'} || undef, 1);

	# Save SSL options
	&parse_tls_directives($conf, $sdirector, 1);

	# Create or update
	if ($in{'new'}) {
		&save_directive($conf, $parent, undef, $sdirector, 0);
		}
	}

&flush_file_lines();
&unlock_file($parent->{'file'});
&auto_apply_configuration();
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "sdirector", $in{'old'} || $in{'name'});
&redirect("list_sdirectors.cgi");

