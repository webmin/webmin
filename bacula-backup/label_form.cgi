#!/usr/local/bin/perl
# Show a form for labelling one volume

require './bacula-backup-lib.pl';
&ui_print_header(undef,  $text{'label_title'}, "", "label");

print &ui_form_start("label.cgi", "post");
print &ui_table_start($text{'label_header'}, undef, 2);

# Daemon to label
@storages = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
		 &get_bacula_storages();
print &ui_table_row($text{'label_storage'},
	&ui_select("storage", $in{'storage'},
	 [ map { [ $_->{'name'},
		   &text('clientstatus_on', $_->{'name'}, $_->{'address'}) ] }
	   @storages ]));

@pools = sort { lc($a->{'name'}) cmp lc($b->{'name'}) } &get_bacula_pools();
print &ui_table_row($text{'label_pool'},
	&ui_select("pool", $pools[0]->{'name'},
		[ map { [ $_->{'name'} ] } @pools ]));

# Label to write
print &ui_table_row($text{'label_label'},
		    &ui_textbox("label", undef, 20));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'label_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});
