#!/usr/local/bin/perl
# Create, update or delete a volume pool

require './bacula-backup-lib.pl';
&ReadParse();

if ($in{'status'}) {
	# Go to status page
	&redirect("poolstatus_form.cgi?pool=".&urlize($in{'old'}));
	exit;
	}

$conf = &get_director_config();
$parent = &get_director_config_parent();
@pools = &find("Pool", $conf);

if (!$in{'new'}) {
	$pool = &find_by("Name", $in{'old'}, \@pools);
        $pool || &error($text{'pool_egone'});
	}
else {
	$pool = { 'type' => 1,
		  'name' => 'Pool',
		  'members' => [ ] };
	}

&lock_file($parent->{'file'});
if ($in{'delete'}) {
	# Just delete this one
	$name = &find_value("Name", $pool->{'members'});
	$child = &find_dependency("Pool", $name, [ "Job", "JobDefs" ], $conf);
	$child && &error(&text('pool_echild', $child));
	&save_directive($conf, $parent, $pool, undef, 0);
	}
else {
	# Validate and store inputs
	&error_setup($text{'pool_err'});
	$in{'name'} =~ /\S/ || &error($text{'pool_ename'});
	if ($in{'new'} || $in{'name'} ne $in{'old'}) {
		$clash = &find_by("Name", $in{'name'}, \@pools);
		$clash && &error($text{'pool_eclash'});
		}
	&save_directive($conf, $pool, "Name", $in{'name'}, 1);
	&save_directive($conf, $pool, "Pool Type", $in{'type'}, 1);

	# Max volume jobs
	if ($in{'maxmode'} == 0) {
		&save_directive($conf, $pool, "Maximum Volume Jobs", undef, 1);
		}
	else {
		$in{'max'} =~ /^\d+$/ || &error($text{'pool_emax'});
		&save_directive($conf, $pool, "Maximum Volume Jobs", $in{'max'}, 1);
		}

	# Retention period
	$reten = &parse_period_input("reten");
	$reten || &error($text{'pool_ereten'});
	&save_directive($conf, $pool, "Volume Retention", $reten, 1);

	# Save yes/no options
	&save_directive($conf, $pool, "Recycle", $in{'recycle'} || undef, 1);
	&save_directive($conf, $pool, "AutoPrune", $in{'auto'} || undef, 1);
	if (&get_bacula_version_cached() < 2) {
		&save_directive($conf, $pool, "Accept Any Volume",
				$in{'any'} || undef, 1);
		}
 	&save_directive($conf, $pool, "LabelFormat", $in{'autolabel'} || undef, 1);
	&save_directive($conf, $pool, "Maximum Volume Bytes", $in{'maxvolsize'} || undef, 1);


	# Create or update
	if ($in{'new'}) {
		&save_directive($conf, $parent, undef, $pool, 0);
		}
	}

&flush_file_lines();
&unlock_file($parent->{'file'});
&auto_apply_configuration();
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "pool", $in{'old'} || $in{'name'});
&redirect("list_pools.cgi");

