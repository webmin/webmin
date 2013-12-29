#!/usr/bin/perl
# list_spoof.cgi
# Show spoofing prevention form

require './itsecur-lib.pl';
&can_use_error("spoof");
&header($text{'spoof_title'}, "",
	undef, undef, undef, undef, &apply_button());

print &ui_hr();

print &ui_form_start("save_spoof.cgi", "post");
print &ui_table_start($text{'spoof_header'}, undef, 2);

my ($iface, @nets) = &get_spoof();

print &ui_table_row($text{'spoof_desc'},
                &ui_radio("spoof", ( $iface ? 1 : 0 ), [
                    [0,$text{'spoof_disabled'}."<br>"],[1,$text{'spoof_enabled'}]
                ]).&iface_input("iface", $iface) );

print &ui_table_row($text{'spoof_nets'}, &ui_textarea("nets", join("\n", @nets), 5, 40) ); 
print &ui_table_end();
print "<p>";
print &ui_submit($text{'save'});
print &ui_form_end(undef,undef,1);
&can_edit_disable("spoof");

print &ui_hr();
&footer("", $text{'index_return'});
