#!/usr/local/bin/perl
# convert.cgi
# Convert unix to webmin users

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, $config_directory);
&ReadParse();
&error_setup($text{'convert_err'});
$access{'sync'} && $access{'create'} || &error($text{'convert_ecannot'});
&foreign_require("useradmin", "user-lib.pl");

# Validate inputs
my (%users, %nusers, $gid);
if ($access{'gassign'} ne '*') {
	my @gcan = split(/\s+/, $access{'gassign'});
	&indexof($in{'wgroup'}, @gcan) >= 0 ||
		&error($text{'convert_ewgroup2'});
	}
if ($in{'conv'} == 1) {
	$in{'users'} =~ /\S/ || &error($text{'convert_eusers'});
	map { $users{$_}++ } split(/\s+/, $in{'users'});
	}
elsif ($in{'conv'} == 2) {
	map { $nusers{$_}++ } split(/\s+/, $in{'nusers'});
	}
elsif ($in{'conv'} == 3) {
	$gid = getgrnam($in{'group'});
	defined($gid) || &error($text{'convert_egroup'});
	}
elsif ($in{'conv'} == 4) {
	$in{'min'} =~ /^\d+$/ || &error($text{'convert_emin'});
	$in{'max'} =~ /^\d+$/ || &error($text{'convert_emax'});
	}

# Get the group to add to
my $group;
my %exists;
foreach my $g (&list_groups()) {
	$group = $g if ($g->{'name'} eq $in{'wgroup'});
	$exists{$g->{'name'}}++;
	}
$group || &error($text{'convert_ewgroup'});

my (@ginfo, @members);
if ($in{'conv'} == 3) {
	# Find secondary members of group
	@ginfo = getgrnam($in{'group'});
	@members = split(/\s+/, $ginfo[3]);
	}

# Build the list of users
my @users;
if ($in{'sync'}) {
	# Can just get from getpw* system calls, as password isn't needed
	@users = ( );
	setpwent();
	while(my @uinfo = getpwent()) {
		push(@users, { 'user' => $uinfo[0],
			       'pass' => $uinfo[1],
			       'uid' => $uinfo[2],
			       'gid' => $uinfo[3],
			       'real' => $uinfo[6],
			       'home' => $uinfo[7],
			       'shell' => $uinfo[8] });
		}
	}
else {
	# Read /etc/passwd
	@users = &useradmin::list_users();
	}

# Convert matching users
&ui_print_header(undef, $text{'convert_title'}, "");
print $text{'convert_msg'},"<p>\n";
print &ui_columns_start([ $text{'convert_user'}, $text{'convert_action'} ]);
map { $exists{$_->{'name'}}++ } &list_users();
my ($skipped, $exists, $invalid, $converted) = (0, 0, 0, 0);
foreach my $u (@users) {
	my $ok;
	if ($in{'conv'} == 0) {
		$ok = 1;
		}
	elsif ($in{'conv'} == 1) {
		$ok = $users{$u->{'user'}};
		}
	elsif ($in{'conv'} == 2) {
		$ok = !$nusers{$u->{'user'}};
		}
	elsif ($in{'conv'} == 3) {
		$ok = $u->{'gid'} == $gid ||
		      &indexof($u->{'user'}, @members) >= 0;
		}
	elsif ($in{'conv'} == 4) {
		$ok = $u->{'uid'} >= $in{'min'} &&
		      $u->{'uid'} <= $in{'max'};
		}
	my $msg;
	if (!$ok) {
		#print &text('convert_skip', $u->{'user'}),"\n";
		$msg = undef;
		$skipped++;
		}
	elsif ($exists{$u->{'user'}}) {
		$msg = "<i>".&text('convert_exists', $u->{'user'})."</i>";
		$exists++;
		}
	elsif ($u->{'user'} !~ /^[A-z0-9\-\_\.]+$/) {
		$msg = "<i>".&text('convert_invalid', $u->{'user'})."</i>";
		$invalid++;
		}
	else {
		# Actually add the user
		$msg = "<b>".&text('convert_added', $u->{'user'})."</b>";
		my $user = { 'name' => $u->{'user'},
			     'pass' => $in{'sync'} ? 'x' : $u->{'pass'},
			     'modules' => $group->{'modules'} };
		&create_user($user);
		foreach my $m (@{$group->{'modules'}}, "") {
			my %groupacl;
			if (&read_file(
			    "$config_directory/$m/$in{'wgroup'}.gacl",
			    \%groupacl)) {
				&write_file(
					"$config_directory/$m/$u->{'user'}.acl",
					\%groupacl);
				}
			}

		push(@{$group->{'members'}}, $u->{'user'});
		$exists{$u->{'user'}}++;
		$converted++;
		}
	print &ui_columns_row([ $u->{'user'}, $msg ]) if ($msg);
	}
endpwent();
print &ui_columns_end();

# Finish off
&modify_group($group->{'name'}, $group);
&restart_miniserv();

# Print summary
print &text('convert_done', $converted, $invalid, $exists, $skipped),"<p>\n";

&ui_print_footer("", $text{'index_return'});

