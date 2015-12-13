#!/usr/local/bin/perl
# edit_referers.cgi
# Display a list of trusted referers

require './usermin-lib.pl';
&ui_print_header(undef, $text{'referers_title'}, "");
&get_usermin_config(\%ugconfig);

print $text{'referers_desc'},"<br>\n";
print &ui_form_start("change_referers.cgi");
print &ui_table_start(undef, undef, 2);

print &ui_table_row($text{'referers_referer'},
	&ui_radio("referer", $ugconfig{'referer'} ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'referers_list'},
	&ui_textarea("referers",
		join("\n", split(/\s+/, $ugconfig{'referers'})),
		5, 60)."<br>\n".
	(!$ugconfig{'referers_none'} ?
		&ui_checkbox("referers_none", 1,
			     $text{'referers_none'}."<br>".
			       $text{'referers_none2'},
			     !$ugconfig{'referers_none'}) : ""));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

