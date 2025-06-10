#!/usr/local/bin/perl
# list_groups.cgi
# Display all groups in the database

require './postgresql-lib.pl';
$access{'users'} || &error($text{'group_ecannot'});
&ui_print_header(undef, $text{'group_title'}, "", "list_groups");

$s = &execute_sql_safe($config{'basedb'}, "select * from pg_user");
foreach $u (@{$s->{'data'}}) {
	$uid{$u->[1]} = $u->[0];
	}

$s = &execute_sql_safe($config{'basedb'}, "select * from pg_group");
@rowlinks = ( &ui_link("edit_group.cgi?new=1",$text{'group_add'}) );
if (@{$s->{'data'}}) {
	print &ui_form_start("delete_groups.cgi", "post");
	unshift(@rowlinks, &select_all_link("d", 0),
			   &select_invert_link("d", 0) );
	print &ui_links_row(\@rowlinks);
	local @tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'group_name'},
				  $text{'group_name'},
				  $text{'group_mems'} ], 100, 0, \@tds);
	foreach $g (@{$s->{'data'}}) {
		local @cols;
		push(@cols, &ui_link("edit_group.cgi?gid=$g->[1]",&html_escape($g->[0])));
		push(@cols, $g->[1]);
		push(@cols, join("&nbsp;|&nbsp;",
		     map { &html_escape($uid{$_}) } &split_array($g->[2])));
		print &ui_checked_columns_row(\@cols, \@tds, "d", $g->[0]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'group_none'}</b><p>\n";
	}
print &ui_links_row(\@rowlinks);
print &ui_form_end([ [ "delete", $text{'user_delete'} ] ]) if (@{$s->{'data'}});

&ui_print_footer("", $text{'index_return'});

