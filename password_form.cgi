#!/usr/local/bin/perl
# password_form.cgi
# Display the form that allows users to change their passwords at login time

BEGIN { push(@INC, ".."); };
use WebminCore;

$pragma_no_cache = 1;
$ENV{'MINISERV_INTERNAL'} || die "Can only be called by miniserv.pl";
&init_config();
&ReadParse();
&header(undef, undef, undef, undef, 1, 1);

print "<center>\n";
if ($in{'expired'} == 2) {
	print &ui_subheading($text{'password_temp'});
	}
else {
	print &ui_subheading($text{'password_expired'});
	}

# Start of the form
print "$text{'password_prefix'}\n";
print &ui_form_start("$gconfig{'webprefix'}/password_change.cgi", "post");
print &ui_hidden("user", $in{'user'});
print &ui_hidden("pam", $in{'pam'});
print &ui_hidden("expired", $in{'expired'});
print &ui_table_start($text{'password_header'}, undef, 2);

# Current username
print &ui_table_row($text{'password_user'},
	&html_escape($in{'user'}));

# Old password
print &ui_table_row($text{'password_old'},
	&ui_password("old", undef, 20));

# New password, twice
print &ui_table_row($text{'password_new1'},
	&ui_password("new1", undef, 20));
print &ui_table_row($text{'password_new2'},
	&ui_password("new2", undef, 20));

# End of form
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'password_ok'} ] ]);
print "</center>\n";
print "$text{'password_postfix'}\n";

&footer();

