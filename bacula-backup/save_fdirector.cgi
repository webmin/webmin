#!/usr/local/bin/perl
# Create, update or delete a file daemon director

require './bacula-backup-lib.pl';
&ReadParse();

$conf = &get_file_config();
$parent = &get_file_config_parent();
@fdirectors = &find("Director", $conf);

if (!$in{'new'}) {
	$fdirector = &find_by("Name", $in{'old'}, \@fdirectors);
        $fdirector || &error($text{'fdirector_egone'});
	}
else {
	$fdirector = { 'type' => 1,
		     'name' => 'Director',
		     'members' => [ ] };
	}

&lock_file($parent->{'file'});
if ($in{'delete'}) {
	# Just delete this one
	$name = &find_value("Name", $fdirector->{'members'});
	&save_directive($conf, $parent, $fdirector, undef, 0);
	}
else {
	# Validate and store inputs
	&error_setup($text{'fdirector_err'});
	$in{'name'} =~ /\S/ || &error($text{'fdirector_ename'});
	if ($in{'new'} || $in{'name'} ne $in{'old'}) {
		$clash = &find_by("Name", $in{'name'}, \@fdirectors);
		$clash && &error($text{'fdirector_eclash'});
		}
	&save_directive($conf, $fdirector, "Name", $in{'name'}, 1);

	$in{'pass'} || &error($text{'fdirector_epass'});
	&save_directive($conf, $fdirector, "Password", $in{'pass'}, 1);

	&save_directive($conf, $fdirector, "Monitor",
			$in{'monitor'} || undef, 1);

        # Save SSL options
        &parse_tls_directives($conf, $fdirector, 1);

	# Create or update
	if ($in{'new'}) {
		&save_directive($conf, $parent, undef, $fdirector, 0);
		}
	}

&flush_file_lines();
&unlock_file($parent->{'file'});
&auto_apply_configuration();
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "fdirector", $in{'old'} || $in{'name'});
&redirect("list_fdirectors.cgi");

