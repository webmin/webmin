#!/usr/local/bin/perl
# list_dbs.cgi
# Display database-level permissions

require './mysql-lib.pl';
$access{'perms'} || &error($text{'perms_ecannot'});
&ui_print_header(undef, $text{'dbs_title'}, "", "dbs");

@rowlinks = ( &ui_link("edit_db.cgi?new=1",$text{'dbs_add'}) );
$d = &execute_sql_safe($master_db, "select * from db order by db");
if (@{$d->{'data'}}) {
	print &ui_form_start("delete_dbs.cgi");
	unshift(@rowlinks, &select_all_link("d", 0),
			   &select_invert_link("d", 0) );
	print &ui_links_row(\@rowlinks);
	@tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'dbs_db'},
				  $text{'dbs_user'},
				  $text{'dbs_host'},
				  $text{'dbs_perms'} ], 100, 0, \@tds);
	$i = -1;
	foreach $u (@{$d->{'data'}}) {
		$i++;
		next if ($access{'perms'} == 2 && !&can_edit_db($u->[1]));
		local @cols;
		push(@cols, "<a href='edit_db.cgi?idx=$i'>".
			($u->[1] eq '%' || $u->[1] eq '' ? $text{'dbs_any'}
					: &html_escape($u->[1]))."</a>");
		push(@cols, $u->[2] eq '' ? $text{'dbs_anon'}
					    : &html_escape($u->[2]));
		push(@cols, $u->[0] eq '%' ? $text{'dbs_any'} :
			    $u->[0] eq '' ? $text{'dbs_hosts'}
					  : &html_escape($u->[0]));
		local @priv;
		for($j=3; $j<=&db_priv_cols()+3-1; $j++) {
			push(@priv, $text{"dbs_priv$j"}) if ($u->[$j] eq 'Y');
			}
		push(@cols, 
			scalar(@priv) == &db_priv_cols() ? $text{'dbs_all'} :
			!@priv ? $text{'dbs_none'} : join("&nbsp;| ", @priv));
		print &ui_checked_columns_row(\@cols, \@tds,
				"d", join(" ", $u->[0], $u->[1], $u->[2]));
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'dbs_empty'}</b> <p>\n";
	}
print &ui_links_row(\@rowlinks);
print &ui_form_end([ [ "delete", $text{'users_delete'} ]]) if (@{$d->{'data'}});

&ui_print_footer("", $text{'index_return'});

