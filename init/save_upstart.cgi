#!/usr/local/bin/perl
# Create, update or delete an upstart service

require './init-lib.pl';
&error_setup($text{'upstart_err'});
$access{'bootup'} || &error($text{'edit_ecannot'});
&ReadParse();

# Get the service
if (!$in{'new'}) {
	@upstarts = &list_upstart_services();
	($u) = grep { $_->{'name'} eq $in{'name'} } @upstarts;
	$u || &error($text{'upstart_egone'});
	$u->{'legacy'} && &error($text{'upstart_elegacy'});
	}

if ($in{'delete'}) {
	# Delete the service
	# XXX
	}
elsif ($in{'new'}) {
	# Create the config file

	# Enable at boot
	}
else {
	# Just save the config file
	$cfile = "/etc/init/$in{'name'}.conf";
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

