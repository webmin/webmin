#!/usr/local/bin/perl
# list_cprivs.cgi
# Display a list of column priviliges

require './mysql-lib.pl';
$access{'perms'} || &error($text{'perms_ecannot'});
&ui_print_header(undef, $text{'cprivs_title'}, "", "cprivs");

$d = &execute_sql_safe($master_db, "select * from columns_priv order by table_name,column_name");
if (@{$d->{'data'}}) {
	print &ui_form_start("delete_cprivs.cgi", "post");
	@rowlinks = ( &select_all_link("d", 0),
		      &select_invert_link("d", 0) );
	print &ui_links_row(\@rowlinks);
	@tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'cprivs_field'},
				  $text{'cprivs_table'},
				  $text{'cprivs_db'},
				  $text{'cprivs_host'},
				  $text{'cprivs_user'},
				  $text{'cprivs_privs'} ], 100, 0, \@tds);
	$i = -1;
	foreach $u (@{$d->{'data'}}) {
		$i++;
		next if ($access{'perms'} == 2 && !&can_edit_db($u->[1]));
		local @cols;
		push(@cols, &ui_link("edit_cpriv.cgi?idx=$i",&html_escape($u->[4])));
		push(@cols, &html_escape($u->[3]));
		push(@cols, &html_escape($u->[1]));
		push(@cols, $u->[0] eq '' || $u->[0] eq '%' ?
		      $text{'cprivs_all'} : &html_escape($u->[0]));
		push(@cols, $u->[2] ? &html_escape($u->[2])
				     : $text{'cprivs_anon'});
		push(@cols, !$u->[6] ? $text{'cprivs_none'} :
		     join("&nbsp;| ",split(/[, ]+/, $u->[6])));
		print &ui_checked_columns_row(\@cols, \@tds, 
					      "d", join(" ", @$u[0..4]));
		}
	print &ui_columns_end();
	print &ui_links_row(\@rowlinks);
	print &ui_form_end([ [ "delete", $text{'users_delete'} ] ]);
	}
else {
	print "<b>$text{'cprivs_norows'}</b><p>\n";
	}
&show_button();

&ui_print_footer("", $text{'index_return'});

sub show_button
{
print &ui_form_start("edit_cpriv.cgi");
local @opts = ( );
local @dbs = sort { $a cmp $b } &list_databases();
if (@dbs > $max_dbs) {
	# Show DB and table fields
	print &ui_submit($text{'cprivs_add2'});
	print $text{'cprivs_db'}," ",&ui_textbox("db", undef, 20)," ",
	      $text{'cprivs_table'}," ",&ui_textbox("table", undef, 20);
	}
else {
	# Show selector
	print &ui_submit($text{'cprivs_add'});
	foreach $d (@dbs) {
		if ($access{'perms'} == 1 || &can_edit_db($d)) {
			foreach $t (&list_tables($d)) {
				push(@opts, "$d.$t");
				}
			}
		}
	print &ui_select("table", undef, \@opts);
	}
print &ui_form_end();
}

