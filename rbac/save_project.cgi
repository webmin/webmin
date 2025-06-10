#!/usr/local/bin/perl
# Create, update or delete one project

require './rbac-lib.pl';
$access{'projects'} || &error($text{'projects_ecannot'});
&ReadParse();
&error_setup($text{'project_err'});

&lock_rbac_files();
$projects = &list_projects();
if (!$in{'new'}) {
	$project = $projects->[$in{'idx'}];
	$logname = $project->{'name'};
	}
else {
	$project = { 'attr' => { } };
	$logname = $in{'name'};
	}

if ($in{'delete'}) {
	# Just delete this project
	&delete_project($project);
	}
else {
	# Check for clash
	if ($in{'new'} || $logname ne $in{'name'}) {
		($clash) = grep { $_->{'name'} eq $in{'name'} } @$projects;
		$clash && &error($text{'project_eclash'});
		}

	# Validate and store inputs
	$in{'name'} =~ /^[^: ]+$/ || &error($text{'project_ename'});
	$project->{'name'} = $in{'name'};
	$in{'id'} =~ /^\d+$/ || &error($text{'project_eid'});
	if ($in{'new'} || $in{'id'} != $project->{'id'}) {
		($clash) = grep { $_->{'id'} == $in{'id'} } @$projects;
		$clash && &error($text{'project_eidclash'});
		}
	$project->{'id'} = $in{'id'};
	$in{'desc'} =~ /^[^:]*$/ || &error($text{'project_edesc'});
	$project->{'desc'} = $in{'desc'};
	$project->{'users'} = &parse_project_members("users");
	$project->{'groups'} = &parse_project_members("groups");

	# Validate resources, and build list of selected rctls
	for($i=0; defined($rctl = $in{"rctl_$i"}); $i++) {
		next if (!$rctl);
		$priv = $in{"priv_$i"};
		$limit = $in{"limit_$i"};
		$action = $in{"action_$i"};
		if ($rctls{$rctl}) {
			$rctls{$rctl} .= ",";
			}
		if ($priv) {
			$limit =~ /^\d+/ ||
				&error(&text('project_elimit', $i+1));
			$rctls{$rctl} .= "($priv,$limit,$action)";
			}
		else {
			$rctls{$rctl} = undef;
			}
		}
	foreach $k (keys %{$project->{'attr'}}) {
		delete($project->{'attr'}->{$k}) if ($k =~ /\./);
		}
	foreach $rctl (keys %rctls) {
		$project->{'attr'}->{$rctl} = $rctls{$rctl};
		}

	# Save pool and max-rss attributes
	delete($project->{'attr'}->{'project.pool'});
	if (!$in{'pool_def'}) {
		$in{'pool'} =~ /^[a-z0-9\.\-]+$/i ||
			&error($text{'project_epool'});
		$project->{'attr'}->{'project.pool'} = $in{'pool'};
		}
	delete($project->{'attr'}->{'rcap.max-rss'});
	if (!$in{'maxrss_def'}) {
		$in{'maxrss'} =~ /^\d+$/ ||
			&error($text{'project_emaxrss'});
		$project->{'attr'}->{'rcap.max-rss'} =
			$in{'maxrss'}*$in{'maxrss_units'};
		}

	# Save or update project
	if ($in{'new'}) {
		&create_project($project);
		}
	else {
		&modify_project($project);
		}
	}

&unlock_rbac_files();
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "project", $logname, $project);
&redirect("list_projects.cgi");

