#!/usr/bin/perl
# Create, update or delete a website

require 'foobar-lib.pl';
ReadParse();
error_setup($text{'save_err'});
lock_file($config{'foobar_conf'});

# Get the old site object
if (!$in{'new'}) {
	my @sites = list_foobar_websites();
        ($site) = grep { $_->{'domain'} eq $in{'old'} } @sites;
	$site || error($text{'save_egone'});
	}

if ($in{'delete'}) {
	# Just delete it
	delete_foobar_website($site);
	}
else {
	# Validate inputs
	$in{'domain'} =~ /^[a-z0-9\.\-\_]+$/i ||
		error($text{'save_edomain'});
	$in{'directory'} =~ /^\// ||
		error($text{'save_edirectory'});
	-d $in{'directory'} ||
		error($text{'save_edirectory2'});
	$site->{'domain'} = $in{'domain'};
	$site->{'directory'} = $in{'directory'};

	# Update or create
	if ($in{'new'}) {
		create_foobar_website($site);
		}
	else {
		modify_foobar_website($site);
		}
	}

# Log the change
unlock_file($config{'foobar_conf'});
apply_configuration();
webmin_log($in{'new'} ? 'create' :
	   $in{'delete'} ? 'delete' : 'modify',
	   'site',
	   $site->{'domain'});
&redirect('');

