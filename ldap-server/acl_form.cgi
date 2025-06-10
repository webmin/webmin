#!/usr/local/bin/perl
# Show the details of one access control rule

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'acl'} || &error($text{'acl_ecannot'});
&ReadParse();

# Get ACLs
if (&get_config_type() == 1) {
	$conf = &get_config();
	@access = &find("access", $conf);
	$hasorder = 0;
	}
else {
	$defdb = &get_default_db();
	$conf = &get_ldif_config();
	@access = &find_ldif("olcAccess", $conf, $defdb);
	$hasorder = 1;
	}

# Page header
if ($in{'new'}) {
	&ui_print_header(undef, $text{'eacl_title1'}, "", "eacl");
	$p = { 'what' => '*',
	       'by' => [ ] };
	}
else {
	&ui_print_header(undef, $text{'eacl_title2'}, "", "eacl");
	$acl = $access[$in{'idx'}];
	$p = &parse_ldap_access($acl);
	}

# Form header
print &ui_form_start("acl_save.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'eacl_header'}, undef, 2);

# Rule ordering
if ($hasorder && !$in{'new'}) {
	print &ui_table_row($text{'eacl_order'},
		$p->{'order'} eq '' ? $text{'eacl_noorder'} : $p->{'order'});
	}

# Granting to what object
$what = $p->{'what'} eq '*' || $p->{'what'} eq '' ? 1 : 0;
if ($p->{'what'} =~ /^dn(\.([^=]+))?="(.*)"$/i ||
    $p->{'what'} =~ /^dn(\.([^=]+))?=(.*)$/i) {
	$dn = $3;
	$style = $2;
	if ($dn eq "") {
		$what = 2;
		}
	}
print &ui_table_row($text{'eacl_what'},
	&ui_radio_table("what", $what,
		[ [ 1, $text{'eacl_what1'} ],
		  [ 2, $text{'eacl_what2'} ],
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
@tds = ( "width=40% nowrap", "width=30%", "width=30%" );
$wtable = &ui_columns_start([ $text{'eacl_who'},
			      $text{'eacl_access'},
			      $text{'eacl_control'} ], 100, 0, \@tds);
$i = 0;
foreach $b (@{$p->{'by'}}, { }, { }, { }) {
	$kwho = $b->{'who'} eq 'self' || $b->{'who'} eq 'users' ||
		$b->{'who'} eq 'anonymous' || $b->{'who'} eq '*' ||
		$b->{'who'} eq '';
	$kacc = !$b->{'access'} ? 'read' :
		&indexof($b->{'access'}, @acl_access_levels) >= 0 ?
			$b->{'access'} : undef;
	$wtable .= &ui_columns_row([
		# Who are we granting?
		&ui_select("wmode_$i",
			   $kwho ? $b->{'who'} : 'other',
			   [ [ '', "&nbsp;" ],
			     [ '*', $text{'eacl_every'} ],
			     [ 'self', $text{'eacl_self'} ],
			     [ 'users', $text{'eacl_users'} ],
			     [ 'anonymous', $text{'eacl_anonymous'} ],
			     [ 'other', $text{'eacl_other'} ] ],
			   1, 0, 0, 0,
			   "style='width:45%' onChange='form.who_$i.disabled = (form.wmode_$i.value != \"other\")'").
		&ui_textbox("who_$i", $kwho ? "" : $b->{'who'}, 50,
			    $kwho, undef, "style='width:45%'"),

		# What access level? Show textbox if complex
		$kacc ? &ui_select("access_$i", $kacc,
				   [ map { [ $_, $text{'access_l'.$_} ] }
					 @acl_access_levels ], 1, 0, 0, 0,
				   "style='width:90%'")
		      : &ui_textbox("access_$i", $b->{'access'}, 20,
				    0, undef, "style='width:90%'"),

		# Additional attrs
		&ui_textbox("control_$i", join(" ", @{$b->{'control'}}), 30,
			    0, undef, "style='width:90%'"),
		], \@tds);
	$i++;
	}
$wtable .= &ui_columns_end();
print &ui_table_row(undef, $wtable, 2);

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

