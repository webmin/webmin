#!/usr/local/bin/perl
# Show a table of all project attributes

require './rbac-lib.pl';
&ui_print_header(undef, $text{'projects_title'}, "", "projects", 0, 0, 0,
		 &help_search_link("resource_controls", "man"));

$projects = &list_projects();
@canprojects = @$projects;
if (@canprojects) {
	print &ui_link("edit_project.cgi?new=1",$text{'projects_add'}),"<br>\n";
	print &ui_columns_start(
		[ $text{'projects_name'},
		  $text{'projects_desc'},
		  $text{'projects_users'},
		  $text{'projects_groups'} ]);
	foreach $p (sort { $a->{'name'} cmp $b->{'name'} } @canprojects) {
		print &ui_columns_row(
			[ &ui_link("edit_project.cgi?idx=$p->{'index'}",
				   $p->{'name'}),
			  $p->{'desc'},
			  &nice_user_list("users", $p->{'users'}),
			  &nice_user_list("groups", $p->{'groups'}),
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'projects_none'}</b><p>\n";
	}
print &ui_link("edit_project.cgi?new=1",$text{'projects_add'}),"<br>\n";

&ui_print_footer("", $text{"index_return"});

# nice_user_list(mode, * or !* or user,user)
sub nice_user_list
{
local $mode = $_[0];
local @users = split(/,/, $_[1]);
local %users = map { $_, 1 } @users;
if ($users{'*'} && @users == 1) {
	return $text{'projects_all'.$mode};
	}
elsif (@users == 0 || $users{'!*'} && @users == 1) {
	return $text{'projects_none'.$mode};
	}
elsif ($users{'*'}) {
	# All except some
	return &text('projects_except'.$mode,
		     join(", ", map { /^\!(.*)/; "<tt>$1</tt>" }
			  grep { /^\!/ } @users[1..$#users]));
	}
elsif ($users{'!*'}) {
	# Only some
	return &text('projects_only'.$mode,
		     join(", ", map { "<tt>$_</tt>" }
			  grep { !/^\!/ } @users[1..$#users]));
	}
else {
	# Only listed
	return &text('projects_only'.$mode,
		     join(", ", map { "<tt>$_</tt>" } @users));
	}
}
