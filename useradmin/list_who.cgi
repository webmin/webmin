#!/usr/local/bin/perl
# list_who.cgi
# Display logged-in users

require './user-lib.pl';
$access{'logins'} || &error($text{'who_ecannot'});
if (&foreign_check("mailboxes")) {
	&foreign_require("mailboxes");
	}

&ui_print_header(undef, $text{'who_title'}, "");

# Build table of users
@whos = &logged_in_users();
@table = ( );
foreach $w (@whos) {
	$tm = defined(&mailboxes::parse_mail_date) ?
		&mailboxes::parse_mail_date($w->{'when'}) : undef;
	push(@table, [
		&ui_link("list_logins.cgi?username=".&urlize($w->{'user'}),
		&html_escape($w->{'user'}) ),
		&html_escape($w->{'tty'}),
		&html_escape($tm ? &make_date($tm) : $w->{'when'}),
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

