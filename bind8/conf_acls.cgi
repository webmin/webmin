#!/usr/local/bin/perl
# conf_acls.cgi
# Display global ACLs

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'acls_ecannot'});
&ui_print_header(undef, $text{'acls_title'}, "",
		 undef, undef, undef, undef, &restart_links());

$conf = &get_config();
@acls = ( &find("acl", $conf), { } );

print &ui_form_start("save_acls.cgi", "post");
print &ui_columns_start([ $text{'acls_name'}, $text{'acls_values'} ]);
for($i=0; $i<@acls; $i++) {
	@cols = ( );
	push(@cols, &ui_textbox("name_$i", $acls[$i]->{'value'}, 15));
	@vals = map { join(" ", $_->{'name'}, @{$_->{'values'}}) }
		    @{$acls[$i]->{'members'}};
	push(@cols, &ui_textarea("values_$i", join("\n", @vals), 5, 60, "off"));
	print &ui_columns_row(\@cols, [ "valign=top" ]);
	}
print &ui_columns_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

