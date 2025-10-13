#!/usr/local/bin/perl
# Show a list of MySQL runtime variables for editing

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'vars_ecannot'});
&ui_print_header(undef, $text{'vars_title'}, "", "vars");
&ReadParse();
%d = map { $_, 1 } split(/\0/, $in{'d'});

print &ui_alert_box(&text('vars_desc', 'edit_cnf.cgi'), 'warn');

# Work out which ones can be edited
my %canedit;
foreach my $v (&list_system_variables()) {
	my $vn = $v->[0];
	$canedit{$vn} = 1;
	$vn =~ s/-/_/g;
	$canedit{$vn} = 1;
	}

# Show search form
print &ui_form_start("list_vars.cgi", undef, undef, "style='float: right;'");
print &ui_textbox("search", $in{'search'}, 25, undef, undef,
	"placeholder=\"$text{'vars_search'}\"")," ",
      &ui_submit($text{'vars_ok'});
print &ui_form_end();

$d = &execute_sql($master_db, "show variables".
		 ($in{'search'} ? " like '%".quotemeta($in{'search'})."%'" : ""));
if (@{$d->{'data'}}) {
	@{$d->{'data'}} = sort {
		# Editing now (highest priority)
		($d{$b->[0]} <=> $d{$a->[0]}) ||
		# Can edit (second priority) 
		($canedit{$b->[0]} <=> $canedit{$a->[0]}) ||
		# Natural sort for equal priority
		$a->[0] cmp $b->[0]
		} @{$d->{'data'}};

	print &ui_form_start("save_vars.cgi");
	print &ui_hidden("search", $in{'search'});
	@tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'vars_name'},
				  $text{'vars_value'} ], 100, 0, \@tds);
	foreach $v (@{$d->{'data'}}) {
		if (!$canedit{$v->[0]}) {
			# Cannot edit, so just show value
			print &ui_columns_row(
				[ "", $v->[0], &html_escape($v->[1]) ], \@tds);
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
	}
else {
	print "<b>",$in{'search'} ? $text{'vars_none2'}
				  : $text{'vars_none'},"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

