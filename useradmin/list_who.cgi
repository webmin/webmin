#!/usr/local/bin/perl
# list_who.cgi
# Display logged-in users

require './user-lib.pl';
%access = &get_module_acl();
$access{'logins'} || &error($text{'who_ecannot'});

&ui_print_header(undef, $text{'who_title'}, "");

@whos = &logged_in_users();
if (@whos) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'who_user'}</b></td> ",
	      "<td><b>$text{'who_tty'}</b></td> ",
	      "<td><b>$text{'who_when'}</b></td> ",
	      "<td><b>$text{'who_from'}</b></td> </tr>\n";
	foreach $w (@whos) {
		print "<tr $cb>\n";
		print "<td><tt><a href='list_logins.cgi?username=$w->{'user'}'>",&html_escape($w->{'user'}),"</a></tt></td>\n";
		print "<td><tt>",&html_escape($w->{'tty'}),"</tt></td>\n";
		print "<td><tt>",&html_escape($w->{'when'}),"</tt></td>\n";
		print "<td><tt>",$w->{'from'} ? &html_escape($w->{'from'}) :
			$text{'logins_local'},"</tt></td>\n";
		print "</tr>\n";
		}
	print "</table><br>\n";
	}
else {
	print "<b>$text{'who_none'}</b> <p>\n";
	}

&ui_print_footer("", $text{'index_return'});

