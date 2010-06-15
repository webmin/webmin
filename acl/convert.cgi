#!/usr/local/bin/perl
# convert.cgi
# Convert unix to webmin users

require './acl-lib.pl';
&ReadParse();
&error_setup($text{'convert_err'});
$access{'sync'} && $access{'create'} || &error($text{'convert_ecannot'});
&foreign_require("useradmin", "user-lib.pl");

# Validate inputs
if ($access{'gassign'} ne '*') {
	@gcan = split(/\s+/, $access{'gassign'});
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
foreach $g (&list_groups()) {
	$group = $g if ($g->{'name'} eq $in{'wgroup'});
	$exists{$g->{'name'}}++;
	}
$group || &error($text{'convert_ewgroup'});

if ($in{'conv'} == 3) {
	# Find secondary members of group
	@ginfo = getgrnam($in{'group'});
	@members = split(/\s+/, $ginfo[3]);
	}

# Convert matching users
&ui_print_header(undef, $text{'convert_title'}, "");
print &ui_subheading($text{'convert_msg'});
print "<table border width=100%><tr><td bgcolor=#c0c0c0><pre>\n";
map { $exists{$_->{'name'}}++ } &list_users();
foreach $u (&foreign_call("useradmin", "list_users")) {
	local $ok;
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
	if (!$ok) {
		print &text('convert_skip', $u->{'user'}),"\n";
		}
	elsif ($exists{$u->{'user'}}) {
		print "<i>",&text('convert_exists', $u->{'user'}),"</i>\n";
		}
	elsif ($u->{'user'} !~ /^[A-z0-9\-\_\.]+$/) {
		print "<i>",&text('convert_invalid', $u->{'user'}),"</i>\n";
		}
	else {
		# Actually add the user
		print "<b>",&text('convert_added', $u->{'user'}),"</b>\n";
		local $user = { 'name' => $u->{'user'},
				'pass' => $in{'sync'} ? 'x' : $u->{'pass'},
				'modules' => $group->{'modules'} };
		&create_user($user);
		foreach $m (@{$group->{'modules'}}, "") {
			local %groupacl;
			if (&read_file("$config_directory/$m/$in{'wgroup'}.gacl",
				       \%groupacl)) {
				&write_file(
					"$config_directory/$m/$u->{'user'}.acl",
					\%groupacl);
				}
			}

		push(@{$group->{'members'}}, $u->{'user'});
		$exists{$u->{'user'}}++;
		}
	}
endpwent() if ($gconfig{'os_type'} ne 'hpux');

# Finish off
&modify_group($group->{'name'}, $group);
&restart_miniserv();

print "</pre></td></tr></table><br>\n";
&ui_print_footer("", $text{'index_return'});

