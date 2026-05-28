#!/usr/local/bin/perl
# Show a form for editing GRUB 2 password protection.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%text);

&ReadParse();
&error_setup($text{'security_err'});
&grub2_assert_acl('security');

my $state = &grub2_read_security_config();

&ui_print_header(undef, $text{'security_title'}, "", "security_current");

# Refuse to edit administrator-owned password scripts we cannot safely merge.
if ($state->{'exists'} && !$state->{'managed'}) {
	print &ui_alert($text{'security_unmanaged'}, 'warning');
	&ui_print_footer("index.cgi", $text{'index_return'});
	exit;
	}

print &ui_form_start("save_security.cgi", "post");
print &ui_table_start($text{'security_header'}, "width=100%", 2);
print &ui_table_row(
	$text{'security_current_state'},
	$state->{'enabled'} ?
		&text('security_current_enabled',
		      &html_escape($state->{'user'} || 'root')) :
		$text{'security_current_disabled'}
);
print &ui_table_row(
	$text{'security_current_hash'},
	$state->{'hash'} ? $text{'security_current_hash_set'} :
			    $text{'security_current_hash_missing'}
);
print &ui_table_hr();
print &ui_table_row(
	&hlink($text{'security_enable'}, "security_enable"),
	&ui_yesno_radio("enabled", $state->{'enabled'} ? 1 : 0)
);
print &ui_table_row(
	&hlink($text{'security_user'}, "security_user"),
	&ui_textbox("user", $state->{'user'} || "root", 30)
);
print &ui_table_hr();
print &ui_table_row(
	$text{'security_password_status'},
	$state->{'enabled'} && $state->{'hash'} ?
		$text{'security_password_keep'} :
		$text{'security_password_required'}
);
# Password fields are optional when keeping the existing PBKDF2 hash.
print &ui_table_row(
	&hlink($text{'security_newpass'}, "security_password"),
	&ui_password("password", "", 30)
);
print &ui_table_row(
	&hlink($text{'security_newpass2'}, "security_password"),
	&ui_password("password2", "", 30)
);
print &ui_table_hr();
# Existing hashes are shown because GRUB stores hashes, not clear text.
print &ui_table_row(
	&hlink($text{'security_hash'}, "security_hash"),
	&ui_textbox("hash", $state->{'hash'} || "", 30, undef, undef, undef,
		    "w-100").
	&ui_tag('div', &ui_note($text{'security_hash_note'}, 0)),
2, undef, undef, 1);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("index.cgi", $text{'index_return'});
