#!/usr/local/bin/perl
# save_mod.cgi
# Update a module line in a service

require './pam-lib.pl';
&ReadParse();
&error_setup($text{'mod_err'});
@pam = &get_pam_config();
$pam = $pam[$in{'idx'}];

&lock_file($pam->{'file'});
if ($in{'delete'}) {
	# Deleting a module
	$mod = $pam->{'mods'}->[$in{'midx'}];
	&delete_module($pam->{'name'}, $mod);
	}
else {
	if ($in{'_module'}) {
		# Adding a new module
		$mod = { 'type' => $in{'_type'},
			 'module' => $in{'_module'} };
		$module = $in{'_module'};
		}
	else {
		# Existing module entry
		$mod = $pam->{'mods'}->[$in{'midx'}];
		$module = $mod->{'module'};
		$module =~ s/^.*\///;
		}
	$mod->{'control'} = $in{'control'};

	if (-r "./$module.pl") {
		# Args selected by UI
		do "./$module.pl";
		if (!$module_has_no_args) {
			foreach $a (split(/\s+/, $mod->{'args'})) {
				if ($a =~ /^([^\s=]+)=(\S*)$/) {
					$args{$1} = $2;
					}
				else {
					$args{$a} = "";
					}
				}
			&parse_module_args($pam, $mod, \%args);
			foreach $a (keys %args) {
				if ($args{$a} eq "") {
					push(@args, $a);
					}
				else {
					push(@args, "$a=$args{$a}");
					}
				}
			$mod->{'args'} = join(" ", @args);
			}
		}
	else {
		# Args entered manually
		$mod->{'args'} = $in{'args'};
		}

	if ($in{'_module'}) {
		# Add the PAM module entry
		&create_module($pam->{'name'}, $mod);
		}
	else {
		# Update the existing entry
		&modify_module($pam->{'name'}, $mod);
		}
	}
&unlock_file($pam->{'file'});
&webmin_log($in{'delete'} ? "delete" : $in{'_module'} ? "create" : "modify",
	    "mod", $pam->{'name'}, $mod);
&redirect("edit_pam.cgi?idx=$in{'idx'}");


