#!/usr/local/bin/perl
# Update an include for a service

require './pam-lib.pl';
&ReadParse();
&error_setup($text{'inc_err'});
@pam = &get_pam_config();
$pam = $pam[$in{'idx'}];

&lock_file($pam->{'file'});
if ($in{'delete'}) {
	# Deleting an include
	$mod = $pam->{'mods'}->[$in{'midx'}];
	&delete_module($pam->{'name'}, $mod);
	}
else {
	if ($in{'_type'}) {
		# Adding a new include
		$mod = { 'type' => $in{'_type'},
			 'control' => 'include',
			 'module' => $in{'inc'} };
		}
	else {
		# Existing module entry
		$mod = $pam->{'mods'}->[$in{'midx'}];
		$mod->{'module'} = $in{'inc'};
		}

	if ($in{'_type'}) {
		# Add the PAM include entry
		&create_module($pam->{'name'}, $mod);
		}
	else {
		# Update the existing include
		&modify_module($pam->{'name'}, $mod);
		}
	}
&unlock_file($pam->{'file'});
&webmin_log($in{'delete'} ? "delete" : $in{'_type'} ? "create" : "modify",
	    "inc", $pam->{'name'}, $mod);
&redirect("edit_pam.cgi?idx=$in{'idx'}");


