#!/usr/local/bin/perl
# Update the @includes for some service

require './pam-lib.pl';
&error_setup($text{'incs_err'});
&ReadParse();
@pams = &get_pam_config();
$pam = $pams[$in{'idx'}];
&lock_file($pam->{'file'});

# Add to, update or remove existing includes
@oldincs = grep { $_->{'include'} } @{$pam->{'mods'}};
@newincs = split(/\0/, $in{'inc'});
for($i=0; $i<@oldincs || $i<@newincs; $i++) {
	if ($oldincs[$i] && $newincs[$i]) {
		# Just update
		$oldincs[$i]->{'include'} = $newincs[$i];
		&modify_module($pam->{'name'}, $oldincs[$i]);
		}
	elsif ($newincs[$i]) {
		# Add to file
		&create_module($pam->{'name'}, { 'include' => $newincs[$i] });
		}
	elsif ($oldincs[$i]) {
		# Remove from file
		&delete_module($pam->{'name'}, $oldincs[$i]);
		}
	}

&unlock_file($pam->{'file'});
&webmin_log("modify", "incs", $pam->{'name'});
&redirect("");

