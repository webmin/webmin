#!/usr/local/bin/perl
# Create, update or delete a systemd service

require './init-lib.pl';
&error_setup($text{'systemd_err'});
$access{'bootup'} || &error($text{'edit_ecannot'});
&ReadParse();
@systemds = &list_systemd_services();

# Get the service
if (!$in{'new'}) {
	($u) = grep { $_->{'name'} eq $in{'name'} } @systemds;
	$u || &error($text{'systemd_egone'});
	$u->{'legacy'} && &error($text{'systemd_elegacy'});
	}

if ($in{'start'} || $in{'stop'} || $in{'restart'}) {
	# Just redirect to the start page
	&redirect("mass_systemd.cgi?d=".&urlize($in{'name'})."&".
		  ($in{'start'} ? "start=1" :
		   $in{'restart'} ? "restart=1" : "stop=1").
		  "&return=".&urlize($in{'name'}));
	exit;
	}

if ($in{'delete'}) {
	# Delete the service
	&disable_at_boot($in{'name'});
	&stop_systemd_service($in{'name'});
	&delete_systemd_service($in{'name'});
	&webmin_log("delete", "systemd", $in{'name'});
	}
elsif ($in{'new'}) {
	# Validate inputs and check for clash
	$in{'name'} .= ".service" if ($in{'name'} !~ /\.service$/);
	$in{'name'} =~ /^[a-z0-9\.\_\-]+$/i ||
		&error($text{'systemd_ename'});
	($clash) = grep { $_->{'name'} eq $in{'name'} } @systemds;
	$clash && &error($text{'systemd_eclash'});
	$in{'desc'} || &error($text{'systemd_edesc'});
	$in{'atstart'} =~ /\S/ || &error($text{'systemd_estart'});

	# Create the config file
	&create_systemd_service($in{'name'}, $in{'desc'}, $in{'atstart'},
				$in{'atstop'});

	# Enable at boot if selected
	if ($in{'boot'} == 0) {
		&disable_at_boot($in{'name'});
		}
	else {
		&enable_at_boot($in{'name'});
		}

	&webmin_log("create", "systemd", $in{'name'});
	}
else {
	# Just save the config file
	$in{'conf'} =~ /\S/ || &error($text{'systemd_econf'});
	$in{'conf'} =~ s/\r//g;
	&open_lock_tempfile(CONF, ">$u->{'file'}");
	&print_tempfile(CONF, $in{'conf'});
	&close_tempfile(CONF);
	&restart_systemd();

	# Enable or disable
	if (defined($in{'boot'})) {
		if ($in{'boot'} == 0) {
			&disable_at_boot($in{'name'});
			}
		else {
			&enable_at_boot($in{'name'});
			}
		}

	&webmin_log("modify", "systemd", $in{'name'});
	}
&redirect("");

