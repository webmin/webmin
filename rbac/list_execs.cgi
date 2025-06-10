#!/usr/local/bin/perl
# Show a table of all execiles

require './rbac-lib.pl';
$access{'execs'} || &error($text{'execs_ecannot'});
&ui_print_header(undef, $text{'execs_title'}, "", "execs");

$execs = &list_exec_attrs();
if (@$execs) {
	print &ui_link("edit_exec.cgi?new=1",$text{'execs_add'}),"<br>\n";
	print &ui_columns_start(
		[ $text{'execs_name'},
		  $text{'execs_policy'},
		  $text{'execs_id'} ]);
	foreach $e (sort { $a->{'name'} cmp $b->{'name'} } @$execs) {
		print &ui_columns_row(
			[ &ui_link("edit_exec.cgi?idx=$e->{'index'}",
				   $e->{'name'}),
			  $text{'execs_p'.$e->{'policy'}},
			  $e->{'id'} eq '*' ? $text{'execs_all'} : $e->{'id'},
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'execs_none'}</b><p>\n";
	}
print &ui_link("edit_exec.cgi?new=1",$text{'execs_add'}),"<br>\n";

&ui_print_footer("", $text{"index_return"});

