#!/usr/local/bin/perl
# edit_group.cgi
# Display a form for editing or creating a group

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'group_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'group_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'group_edit'}, "");
	$s = &execute_sql_safe($config{'basedb'}, "select * from pg_group ".
					     "where grosysid = '$in{'gid'}'");
	@group = @{$s->{'data'}->[0]};
	}

# Start of form block
print &ui_form_start("save_group.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'group_header'}, undef, 2);

# Group name
print &ui_table_row($text{'group_name'},
	&ui_textbox("name", $group[0], 40));

# Group ID, dynamically selected for new ones
if ($in{'new'}) {
	$s = &execute_sql($config{'basedb'},
			  "select max(grosysid) from pg_group");
	$gid = $s->{'data'}->[0]->[0] + 1;
	print &ui_table_row($text{'group_id'},
		&ui_textbox("gid", $gid, 10));
	}
else {
	print &ui_table_row($text{'group_id'}, $group[1]);
	print &ui_hidden("gid", $in{'gid'});
	print &ui_hidden("oldname", $group[0]);
	}

# Group members
($pg_table, $pg_cols) = &get_pg_shadow_table();
$s = &execute_sql($config{'basedb'}, "select $pg_cols from $pg_table");
%uidtouser = map { $_->[1], $_->[0] } @{$s->{'data'}};
if (!$in{'new'}) {
	@mems = map { [ $_, $uidtouser{$_} || $_ ] } &split_array($group[2]);
	}
@users = map { [ $_->[1], $_->[0] ] } @{$s->{'data'}};
print &ui_table_row($text{'group_mems'},
	&ui_multi_select("mems", \@mems, \@users, 10, 1, 0,
			 $text{'group_memsopts'}, $text{'group_memsvals'}));

# End of the form buttons
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_groups.cgi", $text{'group_return'});

