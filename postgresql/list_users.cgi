#!/usr/local/bin/perl
# list_users.cgi
# Display all users in the database

require './postgresql-lib.pl';
$access{'users'} || &error($text{'user_ecannot'});
&ui_print_header(undef, $text{'user_title'}, "", "list_users");

($pg_table, $pg_cols) = &get_pg_shadow_table();
$s = &execute_sql_safe($config{'basedb'}, "select $pg_cols from $pg_table");
print &ui_form_start("delete_users.cgi", "post");
@rowlinks = ( &select_all_link("d", 0),
	      &select_invert_link("d", 0),
	      &ui_link("edit_user.cgi?new=1",$text{'user_add'}) );
print &ui_links_row(\@rowlinks);
print &ui_columns_start([ "", $text{'user_name'},
			  $text{'user_pass'},
			  $text{'user_db'},
			  $text{'user_other'},
			  $text{'user_until'} ], 100);
foreach $u (sort { $a->[0] cmp $b->[0] } @{$s->{'data'}}) {
	local @cols;
	push(@cols, &ui_link("edit_user.cgi?user=$u->[0]",&html_escape($u->[0])));
	push(@cols, $u->[5] ? $text{'yes'} : $text{'no'});
	push(@cols, $u->[2] =~ /t|1/ ? $text{'yes'} : $text{'no'});
	push(@cols, $u->[4] =~ /t|1/ ? $text{'yes'} : $text{'no'});
	push(@cols, $u->[6] ? &html_escape($u->[6])
			     : $text{'user_forever'});
	print &ui_checked_columns_row(\@cols, undef, "d", $u->[0]);
	}
print &ui_columns_end();
print &ui_links_row(\@rowlinks);
print &ui_form_end([ [ "delete", $text{'user_delete'} ] ]);

if (&get_postgresql_version() >= 7 && &foreign_installed("useradmin")) {
	print &ui_hr();
	print "$text{'user_sync'}<p>\n";
	print &ui_form_start("save_sync.cgi");
	print &ui_table_start(undef, undef, 2);

	# When to sync
	print &ui_table_row($text{'user_syncwhen'},
	      &ui_checkbox("sync_create", 1, $text{'user_sync_create'},
			   $config{'sync_create'})."<br>\n".
	      &ui_checkbox("sync_modify", 1, $text{'user_sync_modify'},
			   $config{'sync_modify'})."<br>\n".
	      &ui_checkbox("sync_delete", 1, $text{'user_sync_delete'},
			   $config{'sync_delete'}));

	print &ui_table_end();
	print &ui_form_end([ [ "save", $text{'save'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

