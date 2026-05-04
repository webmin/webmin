#!/usr/local/bin/perl
# Show users in one htpasswd-format file

use strict;
use warnings;
require './nginx-lib.pl';
&foreign_require("htaccess-htpasswd");
our (%text, %in, %access);
&ReadParse();
$in{'file'} || &error($text{'users_efile'});

&ui_print_header("<tt>".&html_escape($in{'file'})."</tt>",
		 $text{'users_title'}, "");

&switch_write_user(1);
my $users = &htaccess_htpasswd::list_users($in{'file'});
&switch_write_user(0);
my @links = ( "<a href='edit_user.cgi?new=1&file=".&urlize($in{'file'})."'>".
	      $text{'users_add'}."</a>" );
if (@$users) {
	print &ui_links_row(\@links);
	my @grid = map { my $h = "<a href='edit_user.cgi".
				 "?user=".&urlize($_->{'user'}).
				 "&file=".&urlize($in{'file'}).
				 "&id=".&urlize($in{'id'}).
				 "&path=".&urlize($in{'path'})."'>".
				 &html_escape($_->{'user'})."</a>";
			 !$_->{'enabled'} ? "<i>$h</i>" : $h } @$users;
	print &ui_grid_table(\@grid, 4, 100);
	}
else {
	print "<b>$text{'users_none'}</b><p>\n";
	}
print &ui_links_row(\@links);

if ($in{'path'}) {
	&ui_print_footer("edit_location.cgi?id=".&urlize($in{'id'}).
			   "&path=".&urlize($in{'path'}),
			 $text{'location_return'});
	}
elsif ($in{'id'}) {
	&ui_print_footer("edit_server.cgi?id=".&urlize($in{'id'}),
			 $text{'server_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

