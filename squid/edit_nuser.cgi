#!/usr/local/bin/perl
# edit_user.cgi
# A form for adding or editing a squid user

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'proxyauth'} || &error($text{'eauth_ecannot'});
&ReadParse();

my %user;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'euser_header'}, "");
	}
else {
	&ui_print_header(undef, $text{'euser_header1'}, "");
	my $conf = &get_config();
	my @users = &list_auth_users(&get_auth_file($conf));
	%user = %{$users[$in{'index'}]};
	}

print &ui_form_start("save_nuser.cgi", "post");
print &ui_hidden("index", $in{'index'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'euser_pud'}, undef, 2);

# Username
print &ui_table_row($text{'euser_u'},
	&ui_textbox("user", $user{'user'}, 30));

# Password
if (%user) {
	print &ui_table_row($text{'euser_p'},
		&ui_radio("pass_def", 1,
			  [ [ 1, $text{'euser_u1'} ],
		            [ 0, &ui_password("pass", undef, 30) ] ]));
	}
else {
	print &ui_table_row($text{'euser_p'},
		&ui_password("pass", undef, 30));
	}

# Enabled?
print &ui_table_row($text{'euser_e'},
	&ui_yesno_radio("enabled", $user{'enabled'} || !%user));

print &ui_table_end();
if (%user) {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("edit_nauth.cgi", $text{'euser_return'},
	"", $text{'index_return'});

