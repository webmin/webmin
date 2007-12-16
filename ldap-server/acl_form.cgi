#!/usr/local/bin/perl
# Show the details of one access control rule

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'acl'} || &error($text{'acl_ecannot'});
&ReadParse();

# Page header
$conf = &get_config();
@access = &find("access", $conf);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'eacl_title1'}, "");
	$p = { 'what' => '*',
	       'by' => [ ] };
	}
else {
	&ui_print_header(undef, $text{'eacl_title2'}, "");
	$acl = $access[$in{'idx'}];
	$p = &parse_ldap_access($acl);
	}

# Form header
print &ui_form_start("acl_save.cgi", "post");
print &ui_table_start($text{'eacl_header'}, undef, 2);

# Granting to what object
$what = $p->{'what'} eq '*' ? 1 : 0;
if ($p->{'what'} =~ /^dn(\.(\S+))?=(.*)$/i) {
	$dn = $3;
	$style = $2;
	}
print &ui_table_row($text{'eacl_what'},
	&ui_radio_table("what", $what,
		[ [ 1, $text{'eacl_what1'} ],
		  [ 0, $text{'eacl_what0'},
		    &ui_textbox("what_dn", $dn, 30)." ".
		    $text{'eacl_mtype'}." ".
		    &ui_select("what_style", $style,
			       [ [ '', $text{'default'} ],
			 	 map { [ $_, $text{'eacl_'.$_} ] }
				     @acl_dn_styles ]) ] ])."\n".
	&ui_checkbox("filter_on", 1, $text{'eacl_filter'}, $p->{'filter'})." ".
	&ui_textbox("filter", $p->{'filter'}, 40)."<br>\n".
	&ui_checkbox("attrs_on", 1, $text{'eacl_attrs'}, $p->{'attrs'})." ".
	&ui_textbox("attrs", $p->{'attrs'}, 40) );

# Access rights table
# XXX

# Form and page end
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}
&ui_print_footer("edit_acl.cgi", $text{'acl_return'});

