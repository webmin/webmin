#!/usr/local/bin/perl
# Display a list of users whose passwords can be changed

require './passwd-lib.pl';
if (!$config{'passwd_cmd'} && !&foreign_check("useradmin")) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print "<p>$text{'index_euseradmin'}<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

if ($access{'mode'} == 1) {
	if ($access{'users'} =~ /^\S+$/) {
		# Just one user - go to him
		&redirect("edit_passwd.cgi?user=$access{'users'}&one=1");
		exit;
		}
	map { $ucan{$_}++ } split(/\s+/, $access{'users'});
	}
elsif ($access{'mode'} == 2) {
	map { $ucannot{$_}++ } split(/\s+/, $access{'users'});
	}
elsif ($access{'mode'} == 3) {
	# Just this user - go to him
	&redirect("edit_passwd.cgi?user=$remote_user&one=1");
	exit;
	}
elsif ($access{'mode'} == 5) {
	%notusers = map { $_, 1 } split(/\s+/, $access{'notusers'});
	foreach $g (split(/\s+/, $access{'users'})) {
		@g = getgrnam($g);
		$gcan{$g[2]}++;
		if ($access{'sec'}) {
			foreach $m (split(/,/, $g[3])) {
				$insec{$m}++;
				}
			}
		}
	}

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Show all unix users who can be edited
setpwent();
while(local @u = getpwent()) {
	if ($access{'mode'} == 0 ||
	    $access{'mode'} == 1 && $ucan{$u[0]} ||
	    $access{'mode'} == 2 && !$ucannot{$u[0]} ||
	    $access{'mode'} == 5 && ($gcan{$u[3]} ||
				     $access{'sec'} && $insec{$u[0]}) &&
				    !$notusers{$u[0]} ||
	    $access{'mode'} == 6 && $u[0] =~ /$access{'users'}/ ||
	    $access{'mode'} == 4 &&
		(!$access{'low'} || $u[2] >= $access{'low'}) &&
		(!$access{'high'} || $u[2] <= $access{'high'})) {
		push(@ulist, \@u);
		if ($config{'max_users'} && @ulist > $config{'max_users'}) {
			# Reached limit already .. no need to go on
			last;
			}
		}
	}
endpwent() if ($gconfig{'os_type'} ne 'hpux');
if ($config{'sort_mode'}) {
	@ulist = sort { lc($a->[0]) cmp lc($b->[0]) } @ulist;
	}
if ($config{'max_users'} && @ulist > $config{'max_users'}) {
	# Show as form for entering a username
	print "$text{'index_toomany'}<br>\n";
	print "<form action=edit_passwd.cgi>\n";
	print "<input type=submit value='$text{'index_user'}'>\n";
	if ($config{'input_type'}) {
		print "<select name=user>\n";
		foreach $u (@ulist) {
			print "<option>$u->[0]\n";
			}
		print "</select>\n";
		}
	else {
		print "<input name=user size=13> ",
		      &user_chooser_button("user",0);
		}
	print "</form>\n";
	}
elsif (@ulist) {
	# Show as table of users
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_header'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	for($i=0; $i<@ulist; $i++) {
		if ($i%4 == 0) { print "<tr>\n"; }
		print "<td width=25%><a href=\"edit_passwd.cgi?",
		      "user=$ulist[$i]->[0]\">",
		      &html_escape($ulist[$i]->[0])."</a></td>\n";
		if ($i%4 == 3) { print "</tr>\n"; }
		}
	while($i++ % 4) { print "<td width=25%></td>\n"; }
	print "</table></td> </tr></table><p>\n";
	}
else {
	# No users available
	print "<b>$text{'index_none'}</b><p>\n";
	}

&ui_print_footer("/", $text{'index'});

