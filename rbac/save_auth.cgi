#!/usr/local/bin/perl
# Create, update or delete one RBAC authorization

require './rbac-lib.pl';
$access{'auths'} || &error($text{'auths_ecannot'});
&ReadParse();
&error_setup($text{'auth_err'});

&lock_rbac_files();
$auths = &list_auth_attrs();
if (!$in{'new'}) {
	$auth = $auths->[$in{'idx'}];
	$logname = $auth->{'name'};
	}
else {
	$auth = { 'attr' => { } };
	$logname = $in{'name'};
	}

if (!$in{'new'}) {
	# Find users of this authorization
	$users = &list_user_attrs();
	foreach $u (@$users) {
		local @auths =
		    split(/,/, $u->{'attr'}->{'auths'});
		$idx = &indexof($logname, @auths);
		if ($idx >= 0) {
			push(@authusers, [ $u, $idx, \@auths ]);
			}
		}
	$profs = &list_prof_attrs();
	foreach $p (@$profs) {
		local @auths =
		    split(/,/, $p->{'attr'}->{'auths'});
		$idx = &indexof($logname, @auths);
		if ($idx >= 0) {
			push(@authprofs, [ $p, $idx, \@auths ]);
			}
		}
	}

if ($in{'delete'}) {
	# Just delete this auth
	@authusers && &error(&text('auth_einuseu',
				   $authusers[0]->[0]->{'user'}));
	@authprofs && &error(&text('auth_einusep',
				   $authprofs[0]->[0]->{'name'}));
	&delete_auth_attr($auth);
	}
else {
	# Check for clash
	if ($in{'new'} || $logname ne $in{'name'}) {
		($clash) = grep { $_->{'name'} eq $in{'name'} } @$auths;
		$clash && &error($text{'auth_eclash'});
		}

	# Validate and store inputs
	$in{'name'} =~ /^[^:]+$/ || &error($text{'auth_ename'});
	$auth->{'name'} = $in{'name'};
	$in{'short'} =~ /^[^:]*$/ || &error($text{'auth_eshort'});
	$auth->{'short'} = $in{'short'};
	$in{'desc'} =~ /^[^:]*$/ || &error($text{'auth_edesc'});
	$auth->{'desc'} = $in{'desc'};

	# Save or update authile
	if ($in{'new'}) {
		&create_auth_attr($auth);
		}
	else {
		&modify_auth_attr($auth);

		# Update other users of this authorization, if renamed
		if ($logname ne $in{'name'}) {
			foreach $au (@authusers) {
				$au->[2]->[$au->[1]] = $in{'name'};
				$au->[0]->{'attr'}->{'auths'} =
					join(",", @{$au->[2]});
				&modify_user_attr($au->[0]);
				}
			foreach $ap (@authprofs) {
				$ap->[2]->[$ap->[1]] = $in{'name'};
				$ap->[0]->{'attr'}->{'auths'} =
					join(",", @{$ap->[2]});
				&modify_prof_attr($ap->[0]);
				}
			}
		}
	}

&unlock_rbac_files();
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "auth", $logname, $auth);
&redirect("list_auths.cgi");

