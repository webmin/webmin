#!/usr/local/bin/perl
# move.cgi
# Move a PAM module line up or down

require './pam-lib.pl';
&ReadParse();
@pams = &get_pam_config();
$pam = $pams[$in{'idx'}];

&lock_file($pam->{'file'});
$swap1 = $pam->{'mods'}->[$in{'midx'}];
$i = $in{'midx'};
do {
	$i += $in{'up'} ? -1 : 1;
	$swap2 = $pam->{'mods'}->[$i];
	} while($swap2->{'type'} ne $swap1->{'type'});
&swap_modules($pam->{'name'}, $swap1, $swap2);
&unlock_file($pam->{'file'});
&webmin_log("move", "mod", $pam->{'name'}, { '1' => $swap1->{'module'},
					     '2' => $swap2->{'module'} });
&redirect("edit_pam.cgi?idx=$in{'idx'}");

