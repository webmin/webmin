#!/usr/local/bin/perl
# edit_defacl.cgi
# Display global ACL options for usermin

require './usermin-lib.pl';
$access{'defacl'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'defacl_title'}, "");

print "$text{'defacl_desc'}<p>\n";
print &ui_form_start("save_defacl.cgi", "post");
print &ui_table_start($text{'defacl_header'}, "width=100%", 4);

&get_usermin_miniserv_config(\%miniserv);
do "$miniserv{'root'}/acl_security.pl";
&read_file("$miniserv{'root'}/defaultacl", \%acl);
&read_file("$config{'usermin_dir'}/user.acl", \%acl);
&acl_security_form(\%acl);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

