#!/usr/local/bin/perl
# Show password quality and change restrictions

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access);
$access{'pass'} || &error($text{'pass_ecannot'});
&ui_print_header(undef, $text{'pass_title'}, "");

my %miniserv;
&get_miniserv_config(\%miniserv);

print &ui_form_start("save_pass.cgi");
print &ui_table_start($text{'pass_header'}, undef, 2);

# Minimum password size
print &ui_table_row($text{'pass_minsize'},
	&ui_opt_textbox("minsize", $miniserv{'pass_minsize'}, 5,
			$text{'pass_nominsize'})." ".$text{'edit_chars'});

# Regexps password must match
print &ui_table_row($text{'pass_regexps'},
	&ui_textarea("regexps",
		join("\n", split(/\t+/, $miniserv{'pass_regexps'})), 5, 60));

# Human-readable description of regexp
print &ui_table_row($text{'pass_regdesc'},
	&ui_textbox("regdesc", $miniserv{'pass_regdesc'}, 60));

# Days before forced change
print &ui_table_row($text{'pass_maxdays'},
	&ui_opt_textbox("maxdays", $miniserv{'pass_maxdays'}, 5,
			$text{'pass_nomaxdays'})." ".$text{'pass_days'});

# Days before lockout
print &ui_table_row($text{'pass_lockdays'},
	&ui_opt_textbox("lockdays", $miniserv{'pass_lockdays'}, 5,
			$text{'pass_nolockdays'})." ".$text{'pass_days'});

# Disallow use of username
print &ui_table_row($text{'pass_nouser'},
	&ui_yesno_radio("nouser", $miniserv{'pass_nouser'}));

# Disallow dictionary words
print &ui_table_row($text{'pass_nodict'},
	&ui_yesno_radio("nodict", $miniserv{'pass_nodict'}));

# Number of old passwords to reject
print &ui_table_row($text{'pass_oldblock'},
	&ui_opt_textbox("oldblock", $miniserv{'pass_oldblock'}, 5,
			$text{'pass_nooldblock'})." ".$text{'pass_pass'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
