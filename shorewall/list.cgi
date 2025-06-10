#!/usr/bin/perl
# list.cgi
# Display the contents of some table

require './shorewall-lib.pl';
&ReadParse();
&can_access($in{'table'}) || &error($text{'list_ecannot'});
&get_clean_table_name(\%in);
&ui_print_header(undef, $text{$in{'tableclean'}."_title"}, "");

$desc = $text{$in{'tableclean'}."_desc"};
print "$desc<p>\n" if ($desc);

$pfunc = &get_parser_func(\%in);
@table = &read_table_file($in{'table'}, $pfunc);
$cfunc = $in{'tableclean'}."_columns";
$cols = &$cfunc() if (defined(&$cfunc));
$nfunc = $in{'tableclean'}."_colnames";
#&debug_message("cfunc = $cfunc");
#&debug_message("nfunc = $nfunc");
if (defined(&$nfunc)) {
	@colnames = &$nfunc();
	}
else {
	@colnames = ( );
	for($j=0; defined($cols) ? ($j<$cols) : ($text{$in{'tableclean'}."_".$j}); $j++) {
		push(@colnames, $text{$in{'tableclean'}."_".$j});
		}
	}

# Work out select/create links
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   &ui_link("edit.cgi?table=$in{'table'}&new=1",
		    $text{$in{'tableclean'}."_add"}) );
if (&version_atleast(3, 3, 3) && &indexof($in{'table'}, @comment_tables) >= 0) {
	push(@links, &ui_link("editcmt.cgi?table=$in{'table'}&new=1",$text{"comment_add"}));
	}

# Show the table
if (@table) {
	print &ui_form_start("delete.cgi", "post");
	print &ui_hidden("table", $in{'table'}),"\n";
	print &ui_links_row(\@links);
	print &ui_columns_start([
		"",
		@colnames,
		(@table > 1 ? ( $text{'list_move'} ) : ( )),
		$text{'list_add'}
		], undef, 0, [ "width=5" ]);

	$rfunc = $in{'tableclean'}."_row";
	for($i=0; $i<@table; $i++) {
		@t = @{$table[$i]};
		local @cols;
		local @tds;
		if ($t[0] =~ /\??COMMENT/) {
			# Special case - a comment line
			push(@cols, "<a href='editcmt.cgi?table=$in{'table'}&".
				    "idx=$i'><i>".join(" ", @t[1..$#t]).
				    "</i></a>" );
			@tds = ( "width=5", "colspan=".scalar(@colnames) );
			}
		else {
			# Some rule or other object
			if (defined(&$rfunc)) {
				@t = &$rfunc(@t);
				}
			for($j=0; $j<@colnames; $j++) {
				if ($j == 0) {
					$lnk = &ui_link("edit.cgi?table=$in{'table'}&idx=$i",$t[$j]);
					}
				else {
					$lnk = $t[$j];
					}
				push(@cols, $lnk);
				}
			@tds = ( "width=5" );
			}
		if (@table > 1) {
			$mover = "";
			if ($i == 0) {
				$mover .= "<img src=images/gap.gif>";
				}
			else {
				$mover .= &ui_link("up.cgi?table=$in{'table'}&idx=$i","<img src=images/up.gif border=0>")."\n";
				}
			if ($i == $#table) {
				$mover .= "<img src=images/gap.gif>";
				}
			else {
				$mover .= &ui_link("down.cgi?table=$in{'table'}&idx=$i","<img src=images/down.gif border=0>")."\n";
				}
			push(@cols, $mover);
			}
		push(@cols,
		      "<a href='edit.cgi?table=$in{'table'}&new=1&before=$i'>".
		      "<img src=images/before.gif border=0></a>\n".
		      "<a href='edit.cgi?table=$in{'table'}&new=1&after=$i'>".
		      "<img src=images/after.gif border=0></a>\n");
		print &ui_checked_columns_row(\@cols, \@tds, "d", $i);
		}
	print &ui_columns_end();
	}
else {
	print "<b>",$text{$in{'tableclean'}."_none"},"</b><p>\n";
	shift(@links); shift(@links);
	}
print &ui_links_row(\@links);
if (@table) {
	print &ui_form_end([ [ "delete", $text{'list_delete'} ] ]);
	}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("manual_form.cgi", $text{'list_manual'},
		      &text('list_manualdesc',
			"<tt>$config{'config_dir'}/$in{'table'}</tt>"),
		      &ui_hidden("table", $in{'table'}));
print &ui_buttons_end();

&ui_print_footer("", $text{'index_return'});
