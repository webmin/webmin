#!/usr/local/bin/perl
# Create, update or delete one RBAC profile

require './rbac-lib.pl';
&ReadParse();
$access{'profs'} == 1 || &error($text{'profs_ecannot'});
&error_setup($text{'prof_err'});

&lock_rbac_files();
$profs = &list_prof_attrs();
if (!$in{'new'}) {
	$prof = $profs->[$in{'idx'}];
	$logname = $prof->{'name'};
	}
else {
	$prof = { 'attr' => { } };
	$logname = $in{'name'};
	}

if (!$in{'new'}) {
	# Find users of this profile
	$users = &list_user_attrs();
	foreach $u (@$users) {
		local @profiles =
		    split(/,/, $u->{'attr'}->{'profiles'});
		$idx = &indexof($logname, @profiles);
		if ($idx >= 0) {
			push(@profusers, [ $u, $idx, \@profiles ]);
			}
		}
	foreach $p (@$profs) {
		local @profiles =
		    split(/,/, $p->{'attr'}->{'profs'});
		$idx = &indexof($logname, @profiles);
		if ($idx >= 0) {
			push(@profprofs, [ $p, $idx, \@profiles ]);
			}
		}
	$execs = &list_exec_attrs();
	foreach $e (@$execs) {
		if ($e->{'name'} eq $logname) {
			push(@profexecs, [ $e ]);
			}
		}
	}

if ($in{'delete'}) {
	# Just delete this prof
	@profusers && &error(&text('prof_einuseu',
				   $profusers[0]->[0]->{'user'}));
	@profprofs && &error(&text('prof_einusep',
				   $profprofs[0]->[0]->{'name'}));
	@profexecs && &error(&text('prof_einusee', scalar(@profexecs)));
	&delete_prof_attr($prof);
	}
else {
	# Check for clash
	if ($in{'new'} || $logname ne $in{'name'}) {
		($clash) = grep { $_->{'name'} eq $in{'name'} } @$profs;
		$clash && &error($text{'prof_eclash'});
		}

	# Validate and store inputs
	$in{'name'} =~ /^[^:,]+$/ || &error($text{'prof_ename'});
	$prof->{'name'} = $in{'name'};
	$in{'desc'} =~ /^[^:]*$/ || &error($text{'prof_edesc'});
	$prof->{'desc'} = $in{'desc'};
	$profiles = &profiles_parse("profiles");
	if ($profiles) {
		@profiles = split(/,/, $profiles);
		&indexof($in{'name'}, @profiles) < 0 ||
			&error($text{'prof_esub'});
		$prof->{'attr'}->{'profs'} = $profiles;
		}
	else {
		delete($prof->{'attr'}->{'profs'});
		}
	$auths = &auths_parse("auths");
	if ($auths) {
		$prof->{'attr'}->{'auths'} = $auths;
		}
	else {
		delete($prof->{'attr'}->{'auths'});
		}

	# Save or update profile
	if ($in{'new'}) {
		&create_prof_attr($prof);
		}
	else {
		&modify_prof_attr($prof);

		# Update other users of this profile, if renamed
		if ($logname ne $in{'name'}) {
			foreach $pu (@profusers) {
				$pu->[2]->[$pu->[1]] = $in{'name'};
				$pu->[0]->{'attr'}->{'profiles'} =
					join(",", @{$pu->[2]});
				&modify_user_attr($pu->[0]);
				}
			foreach $pp (@profprofs) {
				$pp->[2]->[$pp->[1]] = $in{'name'};
				$pp->[0]->{'attr'}->{'profiles'} =
					join(",", @{$pp->[2]});
				&modify_prof_attr($pp->[0]);
				}
			foreach $pe (@profexecs) {
				$pe->[0]->{'name'} = $in{'name'};
				&modify_exec_attr($pe->[0]);
				}
			}
		}
	}

&unlock_rbac_files();
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "prof", $logname, $prof);
&redirect("list_profs.cgi");

