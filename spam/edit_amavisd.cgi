#!/usr/local/bin/perl
# Allow changing of the rule for delivering spam

require './spam-lib.pl';
&ReadParse();
&can_use_check("amavisd");
$conf = &get_config();
&ui_print_header(undef, $text{'amavisd_title'}, "");
	
my $local_cf=$config{'amavisdconf'};
$local_cf=$text{'index_unknown'} if ($local_cf == "");
if (!-r $local_cf ) {
	# Config not found
	print &text('index_aconfig',
		"<tt>$local_cf</tt>",
		"../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer($redirect_url, $text{'index_return'});
	}

print &text('amavisd_desc', "<tt>$pmrc</tt>"),"<p>\n";

# Find the existing recipe

print &ui_form_start("save_procmail.cgi", "post");
print &ui_table_start(undef, undef, 2);
print $form_hiddens;

# Spam destination inputs
# ....

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'amavisd_ok'} ] ]);

&ui_print_footer($redirect_url, $text{'index_return'});

