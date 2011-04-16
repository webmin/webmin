#!/usr/local/bin/perl
# Create, update or delete an upstart service

require './init-lib.pl';
&error_setup($text{'upstart_err'});
$access{'bootup'} || &error($text{'edit_ecannot'});
&ReadParse();
@upstarts = &list_upstart_services();
$cfile = "/etc/init/$in{'name'}.conf";

# Get the service
if (!$in{'new'}) {
	($u) = grep { $_->{'name'} eq $in{'name'} } @upstarts;
	$u || &error($text{'upstart_egone'});
	$u->{'legacy'} && &error($text{'upstart_elegacy'});
	}

if ($in{'delete'}) {
	# Delete the service
	&disable_at_boot($in{'name'});
	&unlink_logged($cfile);
	&webmin_log("delete", "upstart", $in{'name'});
	}
elsif ($in{'new'}) {
	# Validate inputs and check for clash
	$in{'name'} =~ /^[a-z0-9\.\_\-]+$/i ||
		&error($text{'upstart_ename'});
	($clash) = grep { $_->{'name'} eq $in{'name'} } @upstarts;
	$clash && &error($text{'upstart_eclash'});
	$in{'desc'} || &error($text{'upstart_edesc'});
	$in{'server'} =~ /\S/ || &error($text{'upstart_eserver'});
	($bin, $args) = split(/\s+/, $in{'server'});
	&has_command($bin) || &error($text{'upstart_eserver2'});

	# Create the config file
	&open_lock_tempfile(CFILE, ">$cfile");
	&print_tempfile(CFILE,
	  "# $in{'name'}\n".
	  "#\n".
	  "# $in{'desc'}\n".
	  "\n".
	  "description  \"$in{'desc'}\"\n".
	  "\n".
	  "start on runlevel [2345]\n".
	  "stop on runlevel [!2345]\n".
	  "\n"
	  );
	if ($in{'prestart'}) {
		&print_tempfile(CFILE,
		  "pre-start script\n".
		  join("\n",
		    map { "    ".$_."\n" }
			split(/\n/, $in{'prestart'}))."\n".
		  "end script\n".
		  "\n");
		}
	&print_tempfile(CFILE, "exec ".$in{'server'}."\n");
	&close_tempfile(CFILE);

	# Enable at boot if selected
	&enable_at_boot($in{'name'}) if ($in{'boot'});

	&webmin_log("create", "upstart", $in{'name'});
	}
else {
	# Just save the config file
	$in{'conf'} =~ /\S/ || &error($text{'upstart_econf'});
	$in{'conf'} =~ s/\r//g;
	&open_lock_tempfile(CONF, ">$cfile");
	&print_tempfile(CONF, $in{'conf'});
	&close_tempfile(CONF);

	# Enable or disable
	if (defined($in{'boot'})) {
		if ($in{'boot'} == 0) {
			&disable_at_boot($in{'name'});
			}
		else {
			&enable_at_boot($in{'name'});
			}
		}

	&webmin_log("modify", "upstart", $in{'name'});
	}
&redirect("");

