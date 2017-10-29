#!/usr/local/bin/perl
# Display a list of users whose passwords can be changed

require './passwd-lib.pl';

# Show an error if we don't know how to change passwords
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
	foreach $g (split(/\s+/, $access{'groups'})) {
		@g = getgrnam($g);
		$gcan{$g[2]}++;
		if ($access{'sec'}) {
			foreach $m (split(/\s+/, $g[3])) {
				$insec{$m}++;
				}
			}
		}
	}

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Show all unix users who can be edited
setpwent();
my %doneu;
while(local @u = getpwent()) {
	next if ($doneu{$u[0]}++);
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
	print &ui_form_start("edit_passwd.cgi");
	print &ui_submit($text{'index_user'});
	if ($config{'input_type'}) {
		print &ui_select("user", undef,
				 [ map { $_->[0] } @ulist ]);
		}
	else {
		print &ui_user_textbox("user");
		}
	print &ui_form_end();
	}
elsif (@ulist) {
	# Show as table of users
	@grid = ( );
	for($i=0; $i<@ulist; $i++) {
		push(@grid, &ui_link("edit_passwd.cgi?user=".&urlize($ulist[$i]->[0]), &html_escape($ulist[$i]->[0]) ) );
		}
	print &ui_grid_table(\@grid, 4, 100, undef, undef,
			     $text{'index_header'});
	}
else {
	# No users available
	print "<b>$text{'index_none'}</b><p>\n";
	}

&ui_print_footer("/", $text{'index'});

