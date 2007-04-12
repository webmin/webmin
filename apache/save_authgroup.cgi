#!/usr/local/bin/perl
# save_authgroup.cgi
# Save, create or delete a group

require './apache-lib.pl';
require './auth-lib.pl';

&ReadParse();
&allowed_auth_file($in{'file'}) ||
	&error(&text('authg_ecannot', $in{'file'}));
if ($in{'delete'}) {
	# Deleting a group
	&delete_authgroup($in{'file'}, $in{'oldgroup'});
	}
else {
	# Creating or updating
	&error_setup($text{'authg_err'});
	$in{'group'} =~ /\S/ || &error($text{'authg_euser'});
	$in{'group'} !~ /:/ || &error($text{'authg_euser2'});

	$oldg = &get_authgroup($in{'file'}, $in{'oldgroup'});
	$ginfo{'group'} = $in{'group'};
	@mems = split(/\s+/, $in{'members'});
	$ginfo{'members'} = \@mems;

	if (defined($in{'oldgroup'})) {
		# updating an old group
		if ($in{'oldgroup'} ne $in{'group'} &&
		    &get_authgroup($in{'file'}, $in{'group'})) {
			&error(&text('authg_edup', $in{'group'}));
			}
		&save_authgroup($in{'file'}, $in{'oldgroup'}, \%ginfo);
		}
	else {
		# creating a new one
		if (&get_authgroup($in{'file'}, $in{'group'})) {
			&error(&text('authg_edup', $in{'group'}));
			}
		&create_authgroup($in{'file'}, \%ginfo);
		}
	}
&redirect($in{'url'});

