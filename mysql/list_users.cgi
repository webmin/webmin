#!/usr/local/bin/perl
# list_users.cgi
# Display a list of all database users

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'perms_ecannot'});
&ui_print_header(undef, $text{'users_title'}, "", "users");

print &ui_form_start("delete_users.cgi");
@rowlinks = ( &select_all_link("d", 0),
	      &select_invert_link("d", 0),
	      "<a href='edit_user.cgi?new=1'>$text{'users_add'}</a>" );
print &ui_links_row(\@rowlinks);
@tds = ( "width=5" );
print &ui_columns_start([ "",
			  $text{'users_user'},
			  $text{'users_host'},
			  $text{'users_pass'},
			  $text{'users_perms'} ], 100, 0, \@tds);
$d = &execute_sql_safe($master_db, "select * from user order by user");
$i = 0;
foreach $u (@{$d->{'data'}}) {
	local @cols;
	push(@cols, "<a href='edit_user.cgi?idx=$i'>".
		    ($u->[1] ? &html_escape($u->[1]) : $text{'users_anon'}).
		    "</a>");
	push(@cols, $u->[0] eq '' || $u->[0] eq '%' ?
		      $text{'user_any'} : &html_escape($u->[0]));
	push(@cols, &html_escape($u->[2]));
	local @priv;
	for($j=3; $j<=&user_priv_cols()+3-1; $j++) {
		push(@priv, $text{"users_priv$j"}) if ($u->[$j] eq 'Y');
		}
	push(@cols,
		scalar(@priv) == &user_priv_cols() ? $text{'users_all'} :
		!@priv ? $text{'users_none'} : join("&nbsp;| ", @priv));
	print &ui_checked_columns_row(\@cols, \@tds, "d", $u->[0]." ".$u->[1]);
	$i++;
	}
print &ui_columns_end();
print &ui_links_row(\@rowlinks);
print &ui_form_end([ [ "delete", $text{'users_delete'} ] ]);

print "<hr>\n";
print "<form action=save_sync.cgi>\n";
print "$text{'users_sync'}<p>\n";
print "<table><tr><td valign=top>\n";
printf "<input type=checkbox name=sync_create value=1 %s> %s<br>\n",
	$config{'sync_create'} ? "checked" : "", $text{'users_sync_create'};
printf "<input type=checkbox name=sync_modify value=1 %s> %s<br>\n",
	$config{'sync_modify'} ? "checked" : "", $text{'users_sync_modify'};
printf "<input type=checkbox name=sync_delete value=1 %s> %s<br>\n",
	$config{'sync_delete'} ? "checked" : "", $text{'users_sync_delete'};

map { $priv{$_}++ } split(/\s+/, $config{'sync_privs'});
print "</td><td><select name=sync_privs multiple size=5>\n";
for($i=3; $i<=&user_priv_cols()+3-1; $i++) {
	printf "<option value=%d %s>%s\n",
		$i, $priv{$i} ? 'selected' : '',
		$text{"user_priv$i"};
	}
print "</select></td> </tr>\n";
print "<tr> <td colspan=2>$text{'users_sync_host'}\n";
printf "<input type=radio name=host_def value=1 %s> %s\n",
	$config{'sync_host'} ? "" : "checked", $text{'users_sync_def'};
printf "<input type=radio name=host_def value=0 %s> %s\n",
	$config{'sync_host'} ? "checked" : "", $text{'users_sync_sel'};
printf "<input name=host size=30 value='%s'></td> </tr>\n",
	$config{'sync_host'};
print "</table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

