#!/usr/local/bin/perl
# save_mon.cgi
# Create, update or delete a monitor

require './status-lib.pl';
$access{'edit'} || &error($text{'mon_ecannot'});
&ReadParse();
if ($in{'type'}) {
	$in{'type'} =~ /^[a-zA-Z0-9\_\-\.\:]+$/ || &error($text{'mon_etype'});
	$serv->{'type'} = $in{'type'};
	$serv->{'id'} = time();
	}
else {
	$serv = &get_service($in{'id'});
	$serv->{'oldremote'} = $serv->{'remote'};
	}

if ($in{'delete'}) {
	# Delete the monitor
	&delete_service($serv);
	&webmin_log("delete", undef, $serv->{'id'}, $serv);
	}
elsif ($in{'newclone'}) {
	# Redirect to creation form, in clone mode
	&redirect("edit_mon.cgi?type=$serv->{'type'}&clone=$in{'id'}");
	exit(0);
	}
else {
	# Parse and validate inputs
	&error_setup($text{'mon_err'});
	$in{'desc'} || &error($text{'mon_edesc'});
	$serv->{'desc'} = $in{'desc'};

	# Make sure remote monitors exist on remote systems
	@remotes = split(/\0/, $in{'remotes'});
	$newremote = join(" ", @remotes);
	if ($in{'type'} || $serv->{'remote'} ne $newremote) {
		# Only need to check for new monitors
		foreach $r (@remotes) {
			next if ($r eq "*");
			eval { local $main::error_must_die = 1;
			       $ch = &remote_foreign_check($r, 'status') };
			&error(&text('mon_elogin', $r))
			    if ($@ =~ /invalid.*login/i || $@ =~ /HTTP.*401/i);
			if ($@) {
				# If down, let it go for now as we can't really
				# check what is installed
				next;
				#$err = $@;
				#$err =~ s/\s+at\s.*\sline\s+(\d+).*$//;
				#&error(&text('mon_eremote2', $r, $err));
				}
			$ch || &error(&text('mon_estatus', $r));
			&remote_foreign_require($r, 'status',
						'status-lib.pl');
			if ($serv->{'type'} =~ /^(\S+)::(\S+)$/) {
				# Check if module is installed
				$ok = &remote_foreign_call(
				  $r, 'status', "foreign_check", $1);
				}
			else {
				$ok = &remote_eval($r, 'status',
				   "-r \"\$root_directory/status/$serv->{'type'}-monitor.pl\"");
				}
			$ok || &error(&text('mon_ertype', $r));
			}
		}
	$serv->{'remote'} = $newremote;
	$serv->{'groups'} = join(" ", split(/\0/, $in{'groups'}));
	$serv->{'remote'} || $serv->{'groups'} ||
		&error($text{'mon_enoremote'});

	$serv->{'nosched'} = $in{'nosched'};
	$serv->{'notify'} = join(" ", split(/\0/, $in{'notify'}));
	$serv->{'ondown'} = $in{'ondown'};
	$serv->{'onup'} = $in{'onup'};
	$serv->{'ontimeout'} = $in{'ontimeout'};
	$serv->{'runon'} = $in{'runon'};
	$serv->{'clone'} = $in{'clone'};
	$in{'fails'} =~ /^\d+$/ || &error($text{'mon_efails'});
	$serv->{'fails'} = $in{'fails'};
	$serv->{'email'} = $in{'email'};
	$serv->{'tmpl'} = $in{'tmpl'};
	$type = $serv->{'type'};
	if ($in{'depend'} && $in{'depend'} eq $serv->{'id'}) {
		&error($text{'mon_edepend'});
		}
	$serv->{'depend'} = $in{'depend'};

	# Parse inputs for this monitor type
	if ($type =~ /^(\S+)::(\S+)$/) {
		# From another module
		($mod, $mtype) = ($1, $2);
		&foreign_require($mod, "status_monitor.pl");
		if (&foreign_defined($mod, "status_monitor_parse")) {
			&foreign_call($mod, "status_monitor_parse", $mtype, $serv,\%in);
			}
		}
	else {
		# From this module
		do "./${type}-monitor.pl";
		$func = "parse_${type}_dialog";
		if (defined(&$func)) {
			&$func($serv);
			}
		}

	# Save or create the monitor
	&save_service($serv);
	&webmin_log($in{'type'} ? "create" : "modify", undef,
		    $serv->{'id'}, $serv);
	}
&redirect("");

