#!/usr/local/bin/perl
# Show form for force sending a password reset link

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text);
&foreign_require("webmin");
&error_setup($text{'forgot_err'});
&ReadParse();
&can_edit_user($in{'user'}) || &error($text{'edit_euser'});
my $u = &get_user($in{'user'});
$u || &error($text{'edit_egone'});

&ui_print_header(undef, $text{'forgot_title'}, "");

print $text{'forgot_desc'},"<p>\n";

print &ui_form_start("forgot_send.cgi", "post");
print &ui_hidden("user", $in{'user'});
print &ui_table_start($text{'forgot_header'}, undef, 2);

print &ui_table_row($text{'forgot_user'}, "<tt>$u->{'name'}</tt>");

print &ui_table_row($text{'forgot_email'},
	&ui_textbox("email", $u->{'email'}, 60));

if ($u->{'name'} eq 'root') {
	print &ui_table_row($text{'forgot_unix'},
		&ui_opt_textbox("unix", undef, 20, $text{'forgot_unix_def'}));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'forgot_send'} ] ]);

&ui_print_footer("", $text{'index_return'});
