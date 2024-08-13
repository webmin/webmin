#!/usr/local/bin/perl
# list_users.cgi
# Display a list of all database users

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'perms_ecannot'});
&ui_print_header(undef, $text{'users_title'}, "", "users");

print &ui_form_start("delete_users.cgi");
@rowlinks = ( &select_all_link("d", 0),
	      &select_invert_link("d", 0),
	      &ui_link("edit_user.cgi?new=1",$text{'users_add'}) );
print &ui_links_row(\@rowlinks);
@tds = ( "width=5" );
$remote_mysql_version = &get_remote_mysql_version();
print &ui_columns_start([ "",
			  $text{'users_user'},
			  $text{'users_host'},
			  $remote_mysql_version >= 5 ? ( $text{'users_ssl'} )
						     : ( ),
			  $text{'users_perms'} ], 100, 0, \@tds);
$d = &execute_sql_safe($master_db, "select * from user order by user");
%fieldmap = map { $_->{'field'}, $_->{'index'} }
		&table_structure($master_db, "user");
$i = 0;
foreach $u (@{$d->{'data'}}) {
	local @cols;
	push(@cols, "<a href='edit_user.cgi?idx=$i'>".
		    ($u->[1] ? &html_escape($u->[1]) : $text{'users_anon'}).
		    "</a>");
	push(@cols, $u->[0] eq '' || $u->[0] eq '%' ?
		      $text{'user_any'} : &html_escape($u->[0]));
	if ($remote_mysql_version >= 5) {
		$ssl = $u->[$fieldmap{'ssl_type'}];
		push(@cols, $text{'user_ssl_'.lc($ssl)} || $ssl);
		}
	my @priv;
	my ($allprivs, $noprivs) = (1, 1);
	my @priv_fields = &priv_fields('user');
	foreach my $f (@priv_fields) {
		if ($u->[$fieldmap{$f->[0]}] eq 'Y') {
			push(@priv, $f->[1]);
			$noprivs = 0;
			}
		else {
			$allprivs = 0;
			}
		}
	push(@cols, $allprivs ? $text{'users_all'} :
		    $noprivs ? $text{'users_none'} :
		    	&format_privs(\@priv, \@priv_fields));
	print &ui_checked_columns_row(\@cols, \@tds, "d", $u->[0]." ".$u->[1]);
	$i++;
	}
print &ui_columns_end();
print &ui_links_row(\@rowlinks);
print &ui_form_end([ [ "delete", $text{'users_delete'} ] ]);

# Unix / MySQL user syncing
print &ui_hr();
print &ui_form_start("save_sync.cgi");
print "$text{'users_sync'}<p>\n";
print &ui_table_start(undef, undef, 2);

# When to sync
print &ui_table_row($text{'users_syncwhen'},
	&ui_checkbox("sync_create", 1, $text{'users_sync_create'},
		     $config{'sync_create'})."<br>\n".
	&ui_checkbox("sync_modify", 1, $text{'users_sync_modify'},
		     $config{'sync_modify'})."<br>\n".
	&ui_checkbox("sync_delete", 1, $text{'users_sync_delete'},
		     $config{'sync_delete'}));

# Privs for new users
print &ui_table_row($text{'users_sync_privs'},
	&ui_select("sync_privs",
		   [ split(/\s+/, $config{'sync_privs'}) ],
		   [ &priv_fields('user') ],
		   5, 1));

# Hosts for new users
print &ui_table_row($text{'users_sync_host'},
	&ui_opt_textbox("host", $config{'sync_host'}, 30,
			$text{'users_sync_def'}, $text{'users_sync_sel'}));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

