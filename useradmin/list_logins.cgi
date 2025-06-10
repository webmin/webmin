#!/usr/local/bin/perl
# list_logins.cgi
# Display the last login locations, tty, login time and duration

require './user-lib.pl';
&ReadParse();
if (&foreign_check("mailboxes")) {
	&foreign_require("mailboxes");
	}

# Work out who we can list for
$u = $in{'username'};
if (!$access{'logins'}) {
	&error($text{'logins_elist'});
	}
elsif ($access{'logins'} ne "*") {
	$u || &error($text{'logins_elist'});
	local @ul = split(/\s+/, $access{'logins'});
	&indexof($u,@ul) >= 0 ||
		&error(&text('logins_elistu', $u));
	}

&ui_print_header(undef, $text{'logins_title'}, "", "list_logins");

# Build the table data
@table = ( );
foreach $l (&list_last_logins($u, $config{'last_count'})) {
	$tm = defined(&mailboxes::parse_mail_date) ?
		&mailboxes::parse_mail_date($l->[3]) : undef;
	$tm2 = defined(&mailboxes::parse_mail_date) ?
		&mailboxes::parse_mail_date($l->[4]) : undef;
	push(@table, [
		$u ? ( ) : ( "<tt>".&html_escape($l->[0])."</tt>" ),
		&html_escape($l->[2]) || $text{'logins_local'},
		&html_escape($l->[1]),
		$tm ? &make_date($tm) : &html_escape($l->[3]),
		$l->[4] ? ( $tm2 ? &make_date($tm2) : &html_escape($l->[4]),
			    &html_escape($l->[5]) )
			: ( "<i>$text{'logins_still'}</i>", "" ),
		]);
	}

# Show the table
if ($u) {
	my $last_login_max = $config{'last_count'};
	# Sanity check
	if (defined($last_login_max) && $last_login_max <= 0) {
		undef($last_login_max);
		}
	my $last_login_label =
		$last_login_max ? 'logins_head_limit' : 'logins_head'; 
	print &ui_subheading(
		&text($last_login_label,
		      &html_escape($u),
		      &html_escape($last_login_max)));
	}
print &ui_columns_table(
	[ $u ? ( ) : ( $text{'user'} ), $text{'logins_from'},
	  $text{'logins_tty'}, $text{'logins_in'}, $text{'logins_out'},
	  $text{'logins_for'} ],
	100,
	\@table,
	undef,
	0,
	undef,
	$text{'logins_none'},
	);

&ui_print_footer("", $text{'index_return'});

