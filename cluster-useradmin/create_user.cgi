#!/usr/local/bin/perl
# create_user.cgi
# Creates a new user on multiple machines

require './cluster-useradmin-lib.pl';
use Time::Local;
&foreign_require("useradmin", "user-lib.pl");
&error_setup($text{'usave_err'});
&ReadParse();
@hosts = &list_useradmin_hosts();
@servers = &list_servers();

# Strip out \n characters in inputs
$in{'real'} =~ s/\r|\n//g;
$in{'user'} =~ s/\r|\n//g;
$in{'pass'} =~ s/\r|\n//g;
$in{'encpass'} =~ s/\r|\n//g;
$in{'home'} =~ s/\r|\n//g;
$in{'gid'} =~ s/\r|\n//g;
$in{'uid'} =~ s/\r|\n//g;
$in{'othersh'} =~ s/\r|\n//g;

# Validate username
$user{'user'} = $in{'user'};
$in{'user'} =~ /^[^:\t]+$/ ||
	&error(&text('usave_ebadname', $in{'user'}));
$err = &useradmin::check_username_restrictions($in{'user'});
&error($err) if ($err);

$| = 1;
&ui_print_header(undef, $text{'uedit_title2'}, "");

# Work out which hosts to create on
@already = grep { local ($alr) = grep { $_->{'user'} eq $in{'user'} }
				    @{$_->{'users'}};
		  $alr } @hosts;
@hosts = &create_on_parse("usave_header", \@already, $in{'user'});

# Check for username clash
foreach $h (@hosts) {
	($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	foreach $u (@{$h->{'users'}}) {
		if ($u->{'user'} eq $in{'user'}) {
			&error(&text('usave_einuse', $s->{'host'}));
			}
		}
	}

# Validate and store basic inputs
$in{'uid'} =~ /^[0-9]+$/ || &error(&text('usave_euid', $in{'uid'}));
$in{'real'} =~ /^[^:]*$/ || &error(&text('usave_ereal', $in{'real'}));
if ($in{'shell'} eq "*") { $in{'shell'} = $in{'othersh'}; }
$user{'uid'} = $in{'uid'};
($group) = grep { $_->{'group'} eq $in{'gid'} } @{$hosts[0]->{'groups'}};
if ($group) {
	$user{'gid'} = $group->{'gid'};
	}
else {
	$user{'gid'} = getgrnam($in{'gid'});
	}
if ($user{'gid'} eq "") { &error(&text('usave_egid', $in{'gid'})); }
if ($uconfig{'extra_real'}) {
	$in{'office'} =~ /^[^:]*$/ || &error($text{'usave_eoffice'});
	$in{'workph'} =~ /^[^:]*$/ || &error($text{'usave_eworkph'});
	$in{'homeph'} =~ /^[^:]*$/ || &error($text{'usave_ehomeph'});
	$user{'real'} = join(",", $in{'real'}, $in{'office'}, $in{'workph'},
				  $in{'homeph'});
	$user{'real'} .= ",$in{'extra'}" if ($in{'extra'});
	$user{'real'} =~ s/,+$//;
	}
else {
	$user{'real'} = $in{'real'};
	}
if ($uconfig{'home_base'} && $in{'home_base'}) {
	$user{'home'} = &auto_home_dir($uconfig{'home_base'}, $in{'user'});
	}
else {
	$user{'home'} = $in{'home'};
	}
$user{'shell'} = $in{'shell'};
foreach $gid (split(/\0/, $in{'sgid'})) {
	$ingroup{$gid}++;
	}

# Store password input
$crypted = &foreign_call("useradmin", "encrypt_password", $in{'pass'});
if ($in{'passmode'} == 0) {
	if (!$uconfig{'empty_mode'}) {
		local $err = &useradmin::check_password_restrictions(
				"", $user{'user'});
		&error($err) if ($err);
		}
	$user{'pass'} = "";
	}
elsif ($in{'passmode'} == 1) { $user{'pass'} = $uconfig{'lock_string'}; }
elsif ($in{'passmode'} == 2) { $user{'pass'} = $in{'encpass'}; }
elsif ($in{'passmode'} == 3) {
	local $err = &useradmin::check_password_restrictions(
			$in{'pass'}, $user{'user'});
	&error($err) if ($err);
	$user{'pass'} = $crypted;
	}

$pft = &foreign_call("useradmin", "passfiles_type");
if ($pft == 2) {
	# Validate shadow-password inputs
	if ($in{'expired'} ne "" && $in{'expirem'} ne ""
	    && $in{'expirey'} ne "") {
		eval { $expire = timelocal(0, 0, 12, $in{'expired'},
					   $in{'expirem'}-1,
					   $in{'expirey'}-1900); };
		if ($@) { &error("invalid expiry date"); }
		$expire = int($expire / (60*60*24));
		}
	else { $expire = ""; }
	$in{'min'} =~ /^[0-9]*$/ ||
		&error(&text('usave_emin', $in{'min'}));
	$in{'max'} =~ /^[0-9]*$/ ||
		&error(&text('usave_emax', $in{'max'}));
	$in{'warn'} =~ /^[0-9]*$/ ||
		&error(&text('usave_ewarn', $in{'warn'}));
	$in{'inactive'} =~ /^[0-9]*$/ ||
		&error(&text('usave_einactive', $in{'inactive'}));
	$user{'expire'} = $expire;
	$user{'min'} = $in{'min'};
	$user{'max'} = $in{'max'};
	$user{'warn'} = $in{'warn'};
	$user{'inactive'} = $in{'inactive'};
	$user{'change'} = int(time() / (60*60*24));
	}
elsif ($pft == 1 || $pft == 6) {
	# Validate BSD-password inputs
	if ($in{'expired'} ne "" && $in{'expirem'} ne ""
	    && $in{'expirey'} ne "") {
		eval { $expire = timelocal(59, $in{'expiremi'},
					   $in{'expireh'},
					   $in{'expired'},
					   $in{'expirem'}-1,
					   $in{'expirey'}-1900); };
		if ($@) { &error($text{'usave_eexpire'}); }
		}
	else { $expire = ""; }
	if ($in{'changed'} ne "" && $in{'changem'} ne ""
	    && $in{'changey'} ne "") {
		eval { $change = timelocal(59, $in{'changemi'},
					   $in{'changeh'},
					   $in{'changed'},
					   $in{'changem'}-1,
					   $in{'changey'}-1900); };
		if ($@) { &error($text{'usave_echange'}); }
		}
	else { $change = ""; }
	$in{'class'} =~ /^([^: ]*)$/ ||
		&error(&text('usave_eclass', $in{'class'}));
	$user{'expire'} = $expire;
	$user{'change'} = $change;
	$user{'class'} = $in{'class'};
	}
elsif ($pft == 4) {
	# Validate AIX-style password inputs
	if ($in{'expired'} ne "" && $in{'expirem'} ne ""	
		&& $in{'expirey'} ne "" ) {
		# Add a leading zero if only 1 digit long
		$in{'expirem'} =~ s/^(\d)$/0$1/;
		$in{'expired'} =~ s/^(\d)$/0$1/;
		$in{'expireh'} =~ s/^(\d)$/0$1/;
		$in{'expiremi'} =~ s/^(\d)$/0$1/;
		
		# Only use the last two digits of the year
		$in{'expirey'} =~ s/^\d\d(\d\d)$/$1/;
		
		# If the user didn't choose the hour and min make them 01
		$in{'expireh'} = "01" if $in{'expireh'} eq "";
		$in{'expiremi'} = "01" if $in{'expiremi'} eq "";
		$expire="$in{'expirem'}$in{'expired'}$in{'expireh'}$in{'expiremi'}$in{'expirey'}";
		}
	else { $expire = ""; }
	$user{'admin'} = $in{'flags'} =~ /admin/;
	$user{'admchg'} = $in{'flags'} =~ /admchg/;
	$user{'nocheck'} = $in{'flags'} =~ /nocheck/;
	$user{'expire'} = $expire;
	$user{'min'} = $in{'min'};
	$user{'max'} = $in{'max'};
	$user{'warn'} = $in{'warn'};
	$user{'change'} = time();
	}

# Setup error handler for down hosts
sub add_error
{
$add_error_msg = join("", @_);
}
&remote_error_setup(\&add_error);

# Loop through selected hosts to create user
foreach $host (@hosts) {
	$add_error_msg = undef;
	local ($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
	&remote_foreign_require($serv->{'host'}, "useradmin", "user-lib.pl");
	print "<b>",&text('usave_con', &server_name($serv)),"</b><p>\n";
	print "<ul>\n";
	if ($add_error_msg) {
		# Host is down ..
		print &text('usave_failed', $add_error_msg),"<p>\n";
		print "</ul>\n";
		next;
		}
	local @glist;
	if ($in{'sgid'} ne '') {
		@glist = &remote_foreign_call($serv->{'host'}, "useradmin",
					      "list_groups");
		}

	# Run the pre-change command
	$envsgids = join(",", split(/\0/, $in{'sgid'}));
	$envpass = $in{'passmode'} == 3 ? $in{'pass'} : undef;
	&remote_eval($serv->{'host'}, "useradmin", <<EOF
\$ENV{'USERADMIN_USER'} = '$user{'user'}';
\$ENV{'USERADMIN_UID'} = '$user{'uid'}';
\$ENV{'USERADMIN_REAL'} = '$user{'real'}';
\$ENV{'USERADMIN_SHELL'} = '$user{'shell'}';
\$ENV{'USERADMIN_HOME'} = '$user{'home'}';
\$ENV{'USERADMIN_GID'} = '$user{'gid'}';
\$ENV{'USERADMIN_SECONDARY'} = '$envsgids';
\$ENV{'USERADMIN_PASS'} = '$envpass';
\$ENV{'USERADMIN_ACTION'} = 'CREATE_USER';
EOF
	);
	$merr = &remote_foreign_call($serv->{'host'}, "useradmin",
				     "making_changes");
	if (defined($merr)) {
		print &text('usave_emaking', "<tt>$merr</tt>"),"<p>\n";
		print "</ul>\n";
		next;
		}

	# Create the home directory
	local $made_home;
	if ($in{'servs'} || $host eq $hosts[0]) {
		if ($in{'makehome'}) {
			local $exists = &remote_eval($serv->{'host'},
				"useradmin", "-e '$user{'home'}'");
			if (!$exists) {
				print "$text{'usave_mkhome'}<br>\n";
				local $rv = &remote_eval($serv->{'host'}, "useradmin",
					"mkdir('$user{'home'}', oct('$uconfig{'homedir_perms'}')) && chmod(oct('$uconfig{'homedir_perms'}'), '$user{'home'}') ? undef : \$!");
				$rv && &error(&text('usave_emkdir', $rv));
				$rv = &remote_eval($serv->{'host'}, "useradmin",
					"chown($user{'uid'}, $user{'gid'}, '$user{'home'}')");
				$rv || &error(&text('usave_echown', $rv));
				$made_home = 1;
				print "$text{'udel_done'}<p>\n";
				}
			}
		}

	# Save user details
	print "$text{'usave_create'}<br>\n";
	&remote_foreign_call($serv->{'host'}, "useradmin",
			     "create_user", \%user);
	print "$text{'udel_done'}<p>\n";

	# Copy files into user's directory
	if ($in{'servs'} || $host eq $hosts[0]) {
		local $fconfig = &remote_foreign_config($serv->{'host'},
							"useradmin");
		if ($in{'copy_files'} && $made_home) {
			print "$text{'usave_copy'}<br>\n";
			local $uf = $fconfig->{'user_files'};
			$uf =~ s/\$group/$in{'gid'}/g;
			$uf =~ s/\$gid/$user{'gid'}/g;
			&remote_foreign_call($serv->{'host'}, "useradmin",
				"copy_skel_files", $uf, $user{'home'},
				$user{'uid'}, $user{'gid'});
			print "$text{'udel_done'}<p>\n";
			}
		}

	# Update groups
	local @sgids = split(/\0/, $in{'sgid'});
	print "$text{'usave_groups'}<br>\n" if (@sgids);
	foreach $gid (@sgids) {
		foreach $group (@glist) {
			if ($group->{'gid'} == $gid) {
				# Add to this group
				local %ogroup = %$group;
				$group->{'members'} = join(",", $user{'user'},
					split(/,/, $group->{'members'}));
				&remote_foreign_call($serv->{'host'},
					"useradmin", "modify_group",
					\%ogroup, $group);
				}
			}
		}
	print "$text{'udel_done'}<p>\n" if (@sgids);

	# Run the post-change command
	&remote_foreign_call($serv->{'host'}, "useradmin", "made_changes");

	if ($in{'others'}) {
		# Create in other modules on the server
		print "$text{'usave_others'}<br>\n";
		$user{'passmode'} = $in{'passmode'};
		$user{'plainpass'} = $in{'pass'} if ($in{'passmode'} == 3);
		&remote_foreign_call($serv->{'host'}, "useradmin",
				     "other_modules", "useradmin_create_user",
				     \%user);
		print "$text{'udel_done'}<p>\n";
		}

	# Update host
	push(@{$host->{'users'}}, \%user);
	if (@glist) {
		$host->{'groups'} = \@glist;
		}
	&save_useradmin_host($host);
	print "</ul>\n";
	}
&webmin_log("create", "user", $user{'user'}, \%user);

&ui_print_footer("", $text{'index_return'});

