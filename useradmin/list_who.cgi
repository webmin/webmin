#!/usr/local/bin/perl
# list_who.cgi
# Display logged-in users

require './user-lib.pl';
$access{'logins'} || &error($text{'who_ecannot'});

&ui_print_header(undef, $text{'who_title'}, "");

# Build table of users
@whos = &logged_in_users();
@table = ( );
foreach $w (@whos) {
	push(@table, [
		"<a href='list_logins.cgi?username=".&urlize($w->{'user'})."'>".
		&html_escape($w->{'user'})."</a>",
		&html_escape($w->{'tty'}),
		&html_escape($w->{'when'}),
		$w->{'from'} ? &html_escape($w->{'from'})
			     : $text{'logins_local'},
		]);
	}

# Show it
print &ui_columns_table(
	[ $text{'who_user'}, $text{'who_tty'}, $text{'who_when'},
	  $text{'who_from'} ],
	100,
	\@table,
	undef,
	0,
	undef,
	$text{'who_none'},
	);

&ui_print_footer("", $text{'index_return'});

