#!/usr/local/bin/perl
# List all iscsi users

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-server-lib.pl';
our (%text);
my @users = &list_iscsi_users();

&ui_print_header(undef, $text{'users_title'}, "");

my @links = ( &ui_link("edit_user.cgi?new=1",$text{'users_add'}) );
if (@users) {
	unshift(@links, &select_all_link("d"), &select_invert_link("d"));
	print &ui_form_start("delete_users.cgi");
	print &ui_links_row(\@links);
	my @tds = ( "width=5" );
	print &ui_columns_start([ undef, 
				  $text{'users_name'},
				  $text{'users_mode'} ], 50, 0, \@tds);
	foreach my $e (@users) {
		print &ui_checked_columns_row([
			&ui_link("edit_user.cgi?user=$e->{'user'}",&html_escape($e->{'user'})),
			uc($e->{'mode'}),
			], \@tds, "d", $e->{'user'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'users_delete'} ] ]);
	}
else {
	print "<b>$text{'users_none'}</b><p>\n";
	print &ui_links_row(\@links);
	}

&ui_print_footer("", $text{'index_return'});
