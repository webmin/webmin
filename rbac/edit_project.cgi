#!/usr/local/bin/perl
# Show one project

require './rbac-lib.pl';
$access{'projects'} || &error($text{'projects_ecannot'});
&ReadParse();
$projects = &list_projects();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'project_title1'}, "");

	# Pick a free ID
	%taken = map { $_->{'id'}, 1 } @$projects;
	for($id=$config{'base_id'}; $taken{$id}; $id++) { }
	$project = { 'id' => $id };
	}
else {
	&ui_print_header(undef, $text{'project_title2'}, "");
	$project = $projects->[$in{'idx'}];
	}

print &ui_form_start("save_project.cgi", "post");
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_table_start($text{'project_header'}, "width=100%", 2);

print &ui_table_row($text{'project_name'},
		    &ui_textbox("name", $project->{'name'}, 20));

print &ui_table_row($text{'project_id'},
		    &ui_textbox("id", $project->{'id'}, 5));

print &ui_table_row($text{'project_desc'},
		    &ui_textbox("desc", $project->{'desc'}, 60));

print &ui_table_row($text{'project_users'},
		    &project_members_input("users", $project->{'users'}));

print &ui_table_row($text{'project_groups'},
		    &project_members_input("groups", $project->{'groups'}));

# Work out which resources this project has
foreach $a (keys %{$project->{'attr'}}) {
	$v = $project->{'attr'}->{$a};
	if ($a eq "project.pool") {
		# Special case for project pool
		$pool = $v;
		}
	elsif ($a eq "rcap.max-rss") {
		# Special case for max RSS
		$maxrss = $v;
		}
	elsif ($v) {
		while($v =~ /^\(([^,]+),([^,]+),([^,]+)\),?(.*)$/) {
			push(@res, [ $a, $1, $2, $3 ]);
			$v = $4;
			}
		}
	else {
		push(@res, [ $a ]);
		}
	}

print &ui_table_row($text{'project_pool'},
		    &ui_opt_textbox("pool", $pool, 40, $text{'default'}));

print &ui_table_row($text{'project_maxrss'},
		    &ui_radio("maxrss_def", $maxrss ? 0 : 1,
			      [ [ 1, $text{'default'} ],
				[ 0, &ui_bytesbox("maxrss", $maxrss) ] ]));

print &ui_table_end(),"<p>\n";

# Show table for  resources
print &ui_table_start($text{'project_header2'}, "width=100%", 2);
print "<td colspan=2>";
print &ui_columns_start([ $text{'project_rctl'},
			  $text{'project_priv'},
			  $text{'project_limit'},
			  $text{'project_action'} ], "100%");
$i = 0;
foreach $a (@res, [ ], [ ], [ ]) {
	print &ui_columns_row([
		&ui_select("rctl_$i", $a->[0],
		   [ [ "", "&nbsp;" ], map { [ $_ ] } &list_rctls() ], 0, 0, 1),
		&ui_select("priv_$i", $a->[1],
		   [ [ "", $text{'project_nopriv'} ],
		     [ "privileged", $text{'project_privileged'} ],
		     [ "system", $text{'project_system'} ],
		     [ "basic", $text{'project_basic'} ] ],
		   0, 0, $a->[1] ? 1 : 0),
		&ui_textbox("limit_$i", $a->[2], 10),
		&ui_select("action_$i", $a->[3],
			   [ [ "none", $text{'project_none'} ],
			     [ "deny", $text{'project_deny'} ],
			     map { [ "signal=$_->[0]", &text('project_signal', $_->[0], $_->[1]) ] } &list_rctl_signals() ],
			   0, 0, $a->[3] ? 1 : 0),
		]);
	$i++;
	}
print &ui_columns_end();

print "</td>\n";
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("list_projects.cgi", $text{'projects_return'});

