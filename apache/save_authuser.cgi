#!/usr/local/bin/perl
# save_authuser.cgi
# Save, create or delete a user

require './apache-lib.pl';
require './auth-lib.pl';

&ReadParse();
&allowed_auth_file($in{'file'}) ||
	&error(&text('authu_ecannot', $in{'file'}));
if ($in{'delete'}) {
	# Deleting a user
	&delete_authuser($in{'file'}, $in{'olduser'});
	}
else {
	# Creating or updating
	&error_setup($text{'authu_err'});
	$in{'user'} =~ /\S/ || &error($text{'authu_euser'});
	$in{'user'} !~ /:/ || &error($text{'authu_euser2'});

	$oldu = &get_authuser($in{'file'}, $in{'olduser'});
	$uinfo{'user'} = $in{'user'};
	if ($in{'mode'}) {
		$uinfo{'pass'} = $in{'enc'};
		}
	else {
		$salt = chr(int(rand(26))+65).chr(int(rand(26))+65);
		$uinfo{'pass'} = &unix_crypt($in{'pass'}, $salt);
		}

	if (defined($in{'olduser'})) {
		# updating an old user
		if ($in{'olduser'} ne $in{'user'} &&
		    &get_authuser($in{'file'}, $in{'user'})) {
			&error(&text('authu_edup', $in{'user'}));
			}
		&save_authuser($in{'file'}, $in{'olduser'}, \%uinfo);
		}
	else {
		# creating a new one
		if (&get_authuser($in{'file'}, $in{'user'})) {
			&error(&text('authu_edup', $in{'user'}));
			}
		&create_authuser($in{'file'}, \%uinfo);
		}
	}
&redirect($in{'url'});

