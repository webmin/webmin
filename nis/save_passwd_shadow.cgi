#!/usr/local/bin/perl
# save_passwd_shadow.cgi
# Create, update or delete a password/shadow files entry

require './nis-lib.pl';
require './md5-lib.pl';
use Time::Local;
&ReadParse();

($t, $lnums, $passwd, $shadow) =
	&table_edit_setup($in{'table'}, $in{'line'}, ':');
if ($in{'delete'}) {
	# Just delete the user
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the user
	&error_setup($text{'passwd_err'});
	$in{'name'} =~ /^[^: \t]+$/ || &error($text{'passwd_ename'});
	$in{'uid'} =~ /^\d+$/ || &error($text{'passwd_euid'});
	$in{'gid'} =~ /^\d+$/ || &error($text{'passwd_egid'});
	$in{'real'} =~ /^[^:]*$/ || &error($text{'passwd_ereal'});
	$in{'home'} =~ /^[^:]+$/ || &error($text{'passwd_ehome'});
	$in{'shell'} ne '' || $in{'other'} =~ /^[^:]+$/ ||
		&error($text{'passwd_eshell'});
	$in{'passmode'} != 2 || $in{'encpass'} =~ /^[^:]*$/ ||
		&error($text{'passwd_epass'});
	%uconfig = &foreign_config("useradmin");
	@passwd = ( $in{'name'}, 'x',
		    $in{'uid'}, $in{'gid'}, $in{'real'},
		    $in{'home'}, $in{'shell'} ? $in{'shell'} : $in{'other'} );
	$pass = $in{'passmode'} == 0 ? "" :
		$in{'passmode'} == 1 ? $uconfig{'lock_string'} :
		$in{'passmode'} == 2 ? $in{'encpass'} :
				       &encrypt_md5($in{'pass'});
	if ($in{'mode'} == 2) {
		# Parse extra shadow inputs
		if ($in{'expired'} ne "" && $in{'expirem'} ne "" &&
		    $in{'expirey'} ne "") {
			eval { $expire = timelocal(0, 0, 12, $in{'expired'},
						   $in{'expirem'}-1,
						   $in{'expirey'}-1900) };
			&error($text{'passwd_eexpire'}) if ($@);
			$expire = int($expire / (60*60*24));
			}
		$in{'min'} =~ /^[0-9]*$/ || &error($text{'passwd_emin'});
		$in{'max'} =~ /^[0-9]*$/ || &error($text{'passwd_emax'});
		$in{'warn'} =~ /^[0-9]*$/ || &error($text{'passwd_ewarn'});
		$in{'inactive'} =~ /^[0-9]*$/ || &error($text{'passwd_einactive'});
		@shadow = ( $in{'name'}, $pass,
			    undef, $in{'min'}, $in{'max'}, $in{'warn'},
			    $in{'inactive'}, $expire, $shadow->[8] );
		$shadow[2] = int(time() / (60*60*24))
			if ($shadow[1] ne $shadow->[1]);
		}
	elsif ($in{'mode'} == 1) {
		@shadow = ( $in{'name'}, $pass,
			    @$shadow[2..8] );
		}
	else {
		$passwd[1] = $pass;
		}

	if ($in{'line'} eq '') {
		&table_add($t, ":", \@passwd, \@shadow);
		}
	else {
		&table_update($t, $lnums, ":", \@passwd, \@shadow);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

