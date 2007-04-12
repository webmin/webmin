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
		push(@cols, "<a href='edit_cpriv.cgi?idx=$i'>".
			    &html_escape($u->[4])."</a>");
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
print "<form action=edit_cpriv.cgi>\n";
print "<input type=submit value='$text{'cprivs_add'}'>\n";
print "<input type=hidden name=new value=1>\n";
print "<select name=table>\n";
foreach $d (&list_databases()) {
	if ($access{'perms'} == 1 || &can_edit_db($d)) {
		foreach $t (&list_tables($d)) {
			print "<option>$d.$t\n";
			}
		}
	}
print "</select></form>\n";
}

