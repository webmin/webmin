#!/usr/local/bin/perl
# Show a list of MySQL runtime variables for editing

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'vars_ecannot'});
&ui_print_header(undef, $text{'vars_title'}, "", "vars");
&ReadParse();
%d = map { $_, 1 } split(/\0/, $in{'d'});

# Work out which ones can be edited
%canedit = map { $_->[0], 1 } &list_system_variables();

$d = &execute_sql($master_db, "show variables");
print &ui_form_start("save_vars.cgi");
@tds = ( "width=5" );
print &ui_columns_start([ "",
			  $text{'vars_name'},
			  $text{'vars_value'} ], 100, 0, \@tds);
foreach $v (@{$d->{'data'}}) {
	if (!$canedit{$v->[0]}) {
		# Cannot edit, so just show value
		print &ui_columns_row([ "", $v->[0], &html_escape($v->[1]) ],
				      \@tds);
		}
	elsif ($d{$v->[0]}) {
		# Editing now
		print &ui_columns_row([
			"->", "<a name=$v->[0]>$v->[0]</a>",
			&ui_textbox("value_".$v->[0], $v->[1], 40)
			], \@tds);
		}
	else {
		# Can edit
		print &ui_checked_columns_row([
			"<a name=$v->[0]>$v->[0]</a>",
			&html_escape($v->[1])
			], \@tds, "d", $v->[0]);
		}
	}
print &ui_columns_end();
print &ui_form_end([ [ "edit", $text{'vars_edit'} ],
		     %d ? ( [ "save", $text{'save'} ] ) : ( ) ]);

&ui_print_footer("", $text{'index_return'});

