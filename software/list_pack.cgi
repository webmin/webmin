#!/usr/local/bin/perl
# list_pack.cgi
# List all the files in some package

require './software-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'list_title'}, "", "list_pack");

print &ui_subheading(&text('list_files', "<tt>$in{'package'}</tt>"));
print &ui_columns_start([
	$text{'list_path'},
	$text{'list_owner'},
	$text{'list_group'},
	$text{'list_type'},
	$text{'list_size'},
	$text{'list_status'} ], 100);
$n = &check_files($in{'package'}, $in{'version'});
@tds = ( "valign=top", "valign=top", "valign=top",
	 "valign=top", "valign=top", "valign=top" );
for($i=0; $i<$n; $i++) {
	$sz = $files{$i,'size'};
	$ty = $files{$i,'type'};
	local @cols;
	$ls = "file_info.cgi?file=".&urlize($files{$i,'path'});
	$le = "</a>";
	if ($ty == 3 || $ty == 4) {
		# Hard or soft link
		push(@cols, &ui_link($ls, &html_escape($files{$i,'path'}).
		      " -> ".&html_escape($files{$i,'link'})) );
		push(@cols, "", "");
		}
	else {
		my $table = &ui_link($ls, &html_escape($files{$i,'path'}));
		if ($ty == 0 || $ty == 5) {
			$table .= "&nbsp;&nbsp;".&ui_link("view.cgi".
				&html_escape($files{$i,'path'}),
					     $text{'list_view'});
			}
		push(@cols, $table);
		push(@cols, &html_escape($files{$i,'user'}));
		push(@cols, &html_escape($files{$i,'group'}));
		}
	push(@cols, $type_map[$ty]);
	push(@cols, $ty != 0 ? "" : &nice_size($sz));
	$err = $files{$i,'error'};
	if ($err) {
		$err =~ s/</&lt;/g;
		$err =~ s/>/&gt;/g;
		$err =~ s/\n/<br>/g;
		push(@cols, "<font color=#ff0000>$err</font>");
		}
	else {
		push(@cols, $text{'list_ok'});
		}
	print &ui_columns_row(\@cols, \@tds);
	}
print &ui_columns_end();

&ui_print_footer("edit_pack.cgi?package=".&urlize($in{'package'}).
	"&version=".&urlize($in{'version'}), $text{'edit_return'},
	"tree.cgi", $text{'index_treturn'});

