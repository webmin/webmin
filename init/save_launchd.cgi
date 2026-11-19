#!/usr/local/bin/perl
# Create, update or delete a launchd service

require './init-lib.pl';
&error_setup($text{'launchd_err'});
$access{'bootup'} || &error($text{'edit_ecannot'});
&ReadParse();
@launchds = &list_launchd_agents();

# Get the service
if (!$in{'new'}) {
	($u) = grep { $_->{'name'} eq $in{'name'} } @launchds;
	$u || &error($text{'launchd_egone'});
	}

if ($in{'start'} || $in{'stop'} || $in{'restart'}) {
	# Just redirect to the start page
	&redirect("mass_launchd.cgi?d=".&urlize($in{'name'})."&".
		  ($in{'start'} ? "start=1" :
		   $in{'restart'} ? "restart=1" : "stop=1").
		  "&return=".&urlize($in{'name'}));
	exit;
	}

if ($in{'delete'}) {
	# Delete the service
	&delete_launchd_agent($in{'name'});
	&webmin_log("delete", "launchd", $in{'name'});
	}
elsif ($in{'reload'}) {
	# Re-load the service from its config file
	&system_logged("launchctl unload ".quotemeta($u->{'file'})." 2>&1");
	&system_logged("launchctl load ".quotemeta($u->{'file'})." 2>&1");
	&webmin_log("reload", "launchd", $in{'name'});
	}
elsif ($in{'new'}) {
	# Validate inputs and check for clash
	$in{'name'} =~ /^[a-z0-9\.\_\-]+$/i ||
		&error($text{'launchd_ename'});
	($clash) = grep { $_->{'name'} eq $in{'name'} } @launchds;
	$clash && &error($text{'launchd_eclash'});
	$in{'atstart'} =~ /\S/ || &error($text{'launchd_estart'});

	# Create the config file
	&create_launchd_agent($in{'name'}, $in{'atstart'}, $in{'boot'});

	&webmin_log("create", "launchd", $in{'name'});
	}
else {
	# Just save the config file
	$in{'conf'} =~ /\S/ || &error($text{'launchd_econf'});
	$in{'conf'} =~ s/\r//g;
	&open_lock_tempfile(CONF, ">$u->{'file'}");
	&print_tempfile(CONF, $in{'conf'});
	&close_tempfile(CONF);
	&webmin_log("modify", "launchd", $in{'name'});
	}
&redirect("");

