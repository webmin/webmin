#!/usr/bin/perl
# save_service.cgi
# Create, update or delete a service

require './itsecur-lib.pl';
&can_edit_error("services");
&ReadParse();
&lock_itsecur_files();
@servs = &list_services();
if (!$in{'new'}) {
	$serv = $servs[$in{'idx'}];
	}

if ($in{'delete'}) {
	# Check if in use by a rule or other service
	&error_setup($text{'service_err2'});
	@rules = &list_rules();
	foreach $r (@rules) {
		@rservs = split(/,/, $r->{'service'});
		&error($text{'service_einuse'})
			if (&indexof($serv->{'name'}, @rservs) >= 0);
		}
	foreach $s (@servs) {
		&error($text{'service_einuse2'})
			if (&indexof($serv->{'name'}, @{$s->{'others'}}) >= 0);
		}

	# Just delete this service
	splice(@servs, $in{'idx'}, 1);
	&automatic_backup();
	}
else {
	# Validate inputs
	&error_setup($text{'service_err'});
	$in{'name'} =~ /\S/ || &error($text{'service_ename'});
	@others = split(/\0/, $in{'others'});
	for($i=0; defined($in{"proto_$i"}); $i++) {
		next if (!$in{"proto_$i"});
		if ($in{"proto_$i"} eq 'icmp') {
			$in{"port_$i"} =~ /^\d+$/ ||
			   $in{"port_$i"} eq '*' ||
				&error(&text('service_eicmp', $i+1));
			}
		elsif ($in{"proto_$i"} eq 'ip') {
			$in{"port_$i"} =~ /^\d+$/ ||
				&error(&text('service_eip', $i+1));
			}
		else {
			$in{"port_$i"} =~ /^\d+$/ ||
			   $in{"port_$i"} =~ /^\d+\-\d+$/ ||
			   $in{"port_$i"} =~ /^\d+(\s+\d+)*$/ ||
				&error(&text('service_eport', $i+1));
			}
		push(@protos, $in{"proto_$i"});
		push(@ports, $in{"port_$i"});
		}
	@protos || @others || &error($text{'service_enone'});
	#&unique(@protos) == 1 || &error($text{'service_eprotos'});
	if ($in{'new'} || lc($in{'name'}) ne lc($serv->{'name'})) {
		# Check for clash
		($clash) = grep { lc($_->{'name'}) eq lc($in{'name'}) } @servs;
		$clash && &error($text{'service_eclash'});
		}
	$oldname = $serv->{'name'};
	$serv->{'name'} = $in{'name'};
	$serv->{'protos'} = \@protos;
	$serv->{'ports'} = \@ports;
	$serv->{'others'} = \@others;

	if ($in{'new'}) {
		push(@servs, $serv);
		}

	&automatic_backup();
	if (!$in{'new'} && $oldname ne $serv->{'name'}) {
		# Has been re-named .. update all rules!
		@rules = &list_rules();
		foreach $r (@rules) {
			$r->{'service'} = &replace_service_name(
				$r->{'service'}, $oldname, $serv->{'name'});
			}
		&save_rules(@rules);

		# Also update PAT services
		@forwards = &get_pat();
		foreach $f (@forwards) {
			$f->{'service'} = &replace_service_name(
				$f->{'service'}, $oldname, $serv->{'name'});
			}
		&save_pat(@forwards);

		# Also update other services
		foreach $s (@servs) {
			$idx = &indexof($oldname, @{$s->{'others'}});
			if ($idx >= 0) {
				$s->{'others'}->[$idx] = $serv->{'name'};
				}
			}
		}
	}

&save_services(@servs);
&unlock_itsecur_files();
&remote_webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "update",
	    "service", $serv->{'name'}, $serv);
&redirect("list_services.cgi");

# replace_service_name(comma-list, old, new)
sub replace_service_name
{
local @servs = split(/,/, $_[0]);
foreach $s (@servs) {
	$s = $_[2] if ($s eq $_[1]);
	}
return join(",", @servs);
}

