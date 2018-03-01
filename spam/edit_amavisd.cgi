#!/usr/local/bin/perl
# Allow changing of the rule for delivering spam

require './spam-lib.pl';
require './spam-amavis-lib.pl';
&ReadParse();
&can_use_check("amavisd");
&ui_print_header(undef, $text{'amavisd_title'}, "");
	
my $amavis_cf=$config{'amavisdconf'};
$amavis_cf=$text{'index_unknown'} if (!$amavis_cf);
if (!-r $amavis_cf ) {
	# Config not found
	print &text('index_aconfig',
		"<tt>$amavis_cf</tt>",
		"../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer($redirect_url, $text{'index_return'});
	}

$conf = &get_amavis_config();

print &text('amavisd_desc'),"<p>\n";

# Find the existing recipe

print &ui_form_start("save_procmail.cgi", "post");
print &ui_table_start(undef, undef, 2);

# Spam destination inputs
# ....

use Data::Dump qw(dump);
print "<pre>";
dump(@conf);
print "</pre>";

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'amavisd_ok'} ] ]);

&ui_print_footer($redirect_url, $text{'index_return'});

