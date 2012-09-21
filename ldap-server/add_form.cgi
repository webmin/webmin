#!/usr/local/bin/perl
# Show a form for adding a new object

require './ldap-server-lib.pl';
&ReadParse();
$ldap = &connect_ldap_db();
ref($ldap) || &error($ldap);

if ($in{'clone'}) {
	# Get original object
	$rv = $ldap->search(base => $in{'base'},
			    filter => '(objectClass=*)',
			    scope => 'base');
	if (!$rv || $rv->code) {
		&error(&text('oadd_eget', "<tt>$in{'base'}</tt>",
					  &ldap_error($rv)));
		}
	($bo) = $rv->all_entries;
	if ($in{'base'} =~ /^([^=]+)=([^,]+)[, ]*(.*)$/) {
		$dn1 = $1;
		$dn2 = $2;
		$base = $3;
		}
	@classes = $bo->get_value("objectClass");
	foreach $a ($bo->attributes()) {
		next if ($a eq "objectClass");
		local @av = $bo->get_value($a);
		push(@attrs, [ $a, @av == 1 ? $av[0] : \@av ]);
		}
	push(@attrs, [ ], [ ]);
	}
else {
	# Under some object
	$base = $in{'base'};
	$dn1 = "cn";
	for($i=0; $i<$config{'attr_count'}; $i++) {
		push(@attrs, [ ]);
		}
	}

&ui_print_header(undef, $text{'oadd_title'}, "", "oadd");

print &ui_form_start("add.cgi", "post");
print &ui_table_start($text{'oadd_header'}, undef, 2);

# New object
print &ui_table_row($text{'oadd_dn'},
	&ui_textbox("dn1", $dn1, 10)."=".&ui_textbox("dn2", $dn2, 40));

# Parent object
if ($base) {
	print &ui_hidden("base", $base);
	print &ui_table_row($text{'oadd_base'},
		"<tt>$base</tt>");
	}

# Object classes
print &ui_table_row($text{'oadd_classes'},
	&ui_textarea("classes", join("\n", @classes), 4, 40));

# Other attributes
$i = 0;
$atable = &ui_columns_start([ $text{'browser_name'}, $text{'browser_value'} ]);
foreach $a (@attrs) {
	$atable .= &ui_columns_row([
		&ui_textbox("name_$i", $a->[0], 30),
		ref($a->[1]) ?
			&ui_textarea("value_$i", join("\n", @{$a->[1]}),
				     scalar(@{$a->[1]}), 50) :
			&ui_textbox("value_$i", $a->[1], 50),
		]);
	$i++;
	}
$atable .= &ui_columns_end();
print &ui_table_row($text{'oadd_attrs'},
	$atable);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("edit_browser.cgi?base=".&urlize($in{'base'}),
		 $text{'browser_return'});
