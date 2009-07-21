#!/usr/local/bin/perl
# Show a form for creating a new base DN for something

require './ldap-server-lib.pl';
&ui_print_header(undef, $text{'create_title'}, "");
$access{'create'} || &error($text{'create_ecannot'});

print $text{'create_desc'},"<p>\n";
print &ui_form_start("create.cgi", "post");
print &ui_table_start($text{'create_header'}, undef, 2);

# Domain or DN
$dn = &get_ldap_base();
$dom = &get_system_hostname();
if ($dom =~ /^([^\.]+)\.([^\.]+\.\S+)$/) {
	$dom = $2;	# Just domain name
	}
print &ui_table_row($text{'create_dn'},
	&ui_radio_table("mode", 0,
		[ [ 0, $text{'create_dn0'}, &ui_textbox("domain", $dom, 50) ],
		  [ 1, $text{'create_dn1'}, &ui_textbox("dn", $dn, 50) ] ]));

# Example to create
print &ui_table_row($text{'create_example'},
	&ui_radio("example", 0,
		  [ [ 0, $text{'no'} ],
		    [ 1, $text{'create_unix'} ],
		    [ 2, $text{'create_mail'} ],
		    [ 4, $text{'create_group'} ],
		    [ 3, $text{'create_virt'} ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});


