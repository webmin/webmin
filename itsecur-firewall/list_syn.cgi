#!/usr/bin/perl
# list_syn.cgi
# Show syn attack prevention form

require './itsecur-lib.pl';
&can_use_error("syn");
&header($text{'syn_title'}, "",
	undef, undef, undef, undef, &apply_button());

print &ui_hr();

print &ui_form_start("save_syn.cgi", "post");
print &ui_table_start($text{'syn_header'}, undef, 2);

my ($flood, $spoof, $fin) = &get_syn();

print &ui_table_row($text{'syn_flood'},
                    &ui_yesno_radio("flood", ($flood ? 1 : 0 ), 1, 0 )
                    );
 
print &ui_table_row($text{'syn_spoof'},
                    &ui_yesno_radio("spoof", ($spoof ? 1 : 0 ), 1, 0 )
                    );

print &ui_table_row($text{'syn_fin'},
                    &ui_yesno_radio("fin", ($fin ? 1 : 0 ), 1, 0 )
                    );

print &ui_table_end();
print "<p>";
print &ui_submit($text{'save'});
print &ui_form_end(undef,undef,1);
&can_edit_disable("syn");

print &ui_hr();
&footer("", $text{'index_return'});
