#!/usr/local/bin/perl
# list_hosts.cgi
# Display host-level permissions

require './mysql-lib.pl';
$access{'perms'} || &error($text{'perms_ecannot'});
&ui_print_header(undef, $text{'hosts_title'}, "");

$d = &execute_sql_safe($master_db, "select * from host order by host");
@rowlinks = ( &ui_link("edit_host.cgi?new=1",$text{'hosts_add'}) );
if (@{$d->{'data'}}) {
	print &ui_form_start("delete_hosts.cgi");
	unshift(@rowlinks, &select_all_link("d", 0),
			   &select_invert_link("d", 0) );
	print &ui_links_row(\@rowlinks);
	@tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'hosts_db'},
				  $text{'hosts_host'},
				  $text{'hosts_perms'} ], 100, 0, \@tds);
	$i = -1;
	foreach $u (@{$d->{'data'}}) {
		$i++;
		next if ($access{'perms'} == 2 && !&can_edit_db($u->[1]));
		local @cols;
		push(@cols, "<a href='edit_host.cgi?idx=$i'>".
			($u->[1] eq '%' || $u->[1] eq '' ? $text{'hosts_any'}
				: &html_escape($u->[1]))."</a>");
		push(@cols, $u->[0] eq '%' || $u->[0] eq '' ?
				$text{'hosts_any'} : &html_escape($u->[0]));
		local @priv;
		for($j=2; $j<=&db_priv_cols()+2-1; $j++) {
			push(@priv, $text{"hosts_priv$j"}) if ($u->[$j] eq 'Y');
			}
		push(@cols,
			scalar(@priv) == &db_priv_cols() ? $text{'hosts_all'} :
			!@priv ? $text{'hosts_none'} : join("&nbsp;| ", @priv));
		print &ui_checked_columns_row(\@cols, \@tds,
				"d", $u->[0]." ".$u->[1]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'hosts_empty'}</b> <p>\n";
	}
print &ui_links_row(\@rowlinks);
print &ui_form_end([ [ "delete", $text{'users_delete'} ]]) if (@{$d->{'data'}});

&ui_print_footer("", $text{'index_return'});

