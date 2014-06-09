#!/usr/local/bin/perl
# list_tprivs.cgi
# Display a list of table priviliges

require './mysql-lib.pl';
$access{'perms'} || &error($text{'perms_ecannot'});
&ui_print_header(undef, $text{'tprivs_title'}, "", "tprivs");

$d = &execute_sql_safe($master_db, "select * from tables_priv order by table_name");
if (@{$d->{'data'}}) {
	print &ui_form_start("delete_tprivs.cgi", "post");
	@rowlinks = ( &select_all_link("d", 0),
		      &select_invert_link("d", 0) );
	print &ui_links_row(\@rowlinks);
	@tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'tprivs_table'},
				  $text{'tprivs_db'},
				  $text{'tprivs_host'},
				  $text{'tprivs_user'},
				  $text{'tprivs_privs1'},
				  $text{'tprivs_privs2'} ], 100, 0, \@tds);
	$i = -1;
	foreach $u (@{$d->{'data'}}) {
		$i++;
		next if ($access{'perms'} == 2 && !&can_edit_db($u->[1]));
		local @cols;
		push(@cols, &ui_link("edit_tpriv.cgi?idx=$i",&html_escape($u->[3])));
		push(@cols, &html_escape($u->[1]));
		push(@cols, $u->[0] eq '' || $u->[0] eq '%' ?
		      $text{'tprivs_all'} : &html_escape($u->[0]));
		push(@cols, $u->[2] ? &html_escape($u->[2])
				     : $text{'tprivs_anon'});
		push(@cols, !$u->[6] ? $text{'tprivs_none'} :
		     join("&nbsp;| ",split(/[, ]+/, $u->[6])));
		push(@cols, !$u->[7] ? $text{'tprivs_none'} :
		     join("&nbsp;| ",split(/[, ]+/, $u->[7])));
		print &ui_checked_columns_row(\@cols, \@tds,
					      "d", join(" ", @$u[0..3]));
		}
	print &ui_columns_end();
	print &ui_links_row(\@rowlinks);
	print &ui_form_end([ [ "delete", $text{'users_delete'} ] ]);
	}
else {
	print "<b>$text{'tprivs_norows'}</b><p>\n";
	}
&show_button();

&ui_print_footer("", $text{'index_return'});

sub show_button
{
print &ui_form_start("edit_tpriv.cgi");
print &ui_submit($text{'tprivs_add'});
local @dbs = sort { $a cmp $b } &list_databases();
if (@dbs > $max_dbs) {
	# Just show DB name
	print &ui_textbox("db", undef, 20);
	}
else {
	# DB selector
	print &ui_select("db", undef,
		[ grep { $access{'perms'} == 1 || &can_edit_db($_) }
		       &list_databases() ]);
	}
print &ui_form_end();
}

