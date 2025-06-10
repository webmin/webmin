#!/usr/local/bin/perl
# index.cgi
# Show a list of all users whose passwords can be changed

require './cluster-passwd-lib.pl';

# Check if cluster-useradmin is set up
@hosts = &cluster_useradmin::list_useradmin_hosts();
if (!@hosts) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(&text('index_noservers', "../cluster-useradmin/"));
	}
@ulist = grep { &can_edit_passwd($_) } &get_all_users(\@hosts);
if (@ulist == 1) {
	# Can only edit one user, so re-direct to editing form
	&redirect("edit_passwd.cgi?user=$ulist[0]->{'user'}&one=1");
	}

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
if ($config{'sort_mode'}) {
	@ulist = sort { lc($a->{'user'}) cmp lc($b->{'user'}) } @ulist;
	}

print &text('index_hosts', scalar(@hosts)),"<p>\n";

if ($config{'max_users'} && @ulist > $config{'max_users'}) {
	# Show as form for entering a username
	print "$passwd::text{'index_toomany'}<br>\n";
	print &ui_form_start("edit_passwd.cgi");
	print &ui_submit($passwd::text{'index_user'});
	if ($config{'input_type'}) {
		print &ui_select("user", undef,
				 [ map { [ $_->{'user'} ] } @ulist ]);
		}
	else {
		print &ui_user_textbox("user");
		}
	print &ui_form_end();
	}
else {
	# Show as table of users
	my @grid;
	for($i=0; $i<@ulist; $i++) {
		push(@grid, &ui_link("edit_passwd.cgi?user=$ulist[$i]->{'user'}",
				     &html_escape($ulist[$i]->{'user'})));
		}
	print &ui_grid_table(\@grid, 4, 100, undef, undef,
			     $passwd::text{'index_header'});
	}

&ui_print_footer("/", $text{'index'});

