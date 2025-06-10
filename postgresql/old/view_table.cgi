#!/usr/local/bin/perl
# view_table.cgi
# Display all data in some table

require './postgresql-lib.pl';
if ($config{'charset'}) {
	$force_charset = $config{'charset'};
	}
if ($ENV{'CONTENT_TYPE'} !~ /boundary=/) {
	&ReadParse();
	}
else {
	&ReadParseMime();
	}
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
@str = &table_structure($in{'db'}, $in{'table'});
$qt = &quote_table($in{'table'});
if ($in{'field'}) {
	$in{'field'} =~ s/\0.*$//;
	$search = "where ".&quotestr($in{'field'})." ".
		   &make_like($in{'match'}, $in{'for'}, $in{'field'});
	$searchargs = "&field=".&urlize($in{'field'}).
		      "&for=".&urlize($in{'for'}).
		      "&match=".&urlize($in{'match'});
	$searchhids = &ui_hidden("field", $in{'field'})."\n".
		      &ui_hidden("for", $in{'for'})."\n".
		      &ui_hidden("match", $in{'match'})."\n";
        }
elsif ($in{'advanced'}) {
	# An advanced search
	for($i=0; defined($in{"field_$i"}); $i++) {
		if ($in{"field_$i"}) {
			push(@adv, &quotestr($in{"field_$i"})." ".
				   &make_like($in{"match_$i"}, $in{"for_$i"},
					      $in{"field_$i"}));
			$searchargs .= "&field_$i=".&urlize($in{"field_$i"}).
				       "&for_$i=".&urlize($in{"for_$i"}).
				       "&match_$i=".&urlize($in{"match_$i"});
			$searchhids .= &ui_hidden("field_$i", $in{"field_$i"})."\n".
				      &ui_hidden("for_$i", $in{"for_$i"})."\n".
				      &ui_hidden("match_$i", $in{"match_$i"})."\n";
			}
		}
	if (@adv) {
		$search = "where (".join($in{'and'} ? " and " : " or ",
					@adv).")";
		$searchhids .= &ui_hidden("and", $in{'and'})."\n".
			       &ui_hidden("advanced", 1)."\n";
		$searchargs .= "&and=".$in{'and'}.
			       "&advanced=1";
		}
	}

if ($in{'delete'}) {
	# Deleting selected rows
	$count = 0;
	foreach $r (split(/\0/, $in{'row'})) {
		&execute_sql_logged($in{'db'},
			    "delete from $qt where oid = ?", $r);
		$count++;
		}
	&webmin_log("delete", "data", $count, \%in);
	&redirect("view_table.cgi?db=$in{'db'}&".
		  "table=$in{'table'}&start=$in{'start'}&field=$in{'field'}".
		  $searchargs);
	}
elsif ($in{'save'}) {
	# Update edited rows
	$count = 0;
	foreach $r (split(/\0/, $in{'row'})) {
		local @set;
		local @params;
		foreach $t (@str) {
			local $ij = $in{"${r}_$t->{'field'}"};
			local $ijdef = $in{"${r}_$t->{'field'}_def"};
			next if ($ijdef || !defined($ij));
			if (!$config{'blob_mode'} || !&is_blob($str[$i])) {
				$ij =~ s/\r//g;
				}
			push(@set, "$t->{'field'} = ?");
			push(@params, $ij eq "" ? undef : $ij);
			}
		&execute_sql_logged($in{'db'}, "update $qt set ".
			            join(" , ", @set)." where oid = ?",
				    @params, $r);
		$count++;
		}
	&webmin_log("modify", "data", $count, \%in);
	&redirect("view_table.cgi?db=$in{'db'}&".
		  "table=$in{'table'}&start=$in{'start'}&field=$in{'field'}".
		  $searchargs);
	}
elsif ($in{'savenew'}) {
	# Adding a new row
	for($j=0; defined($in{$j}); $j++) {
		if (!$config{'blob_mode'} || !&is_blob($str[$i])) {
			$in{$j} =~ s/\r//g;
			}
		push(@set, $in{$j} eq "" ? undef : $in{$j});
		}
	&execute_sql_logged($in{'db'}, "insert into $qt values (".
			    join(" , ", map { "?" } @set).")", @set);
	&redirect("view_table.cgi?db=$in{'db'}&".
		  "table=$in{'table'}&start=$in{'start'}&field=$in{'field'}".
		  $searchargs);
	&webmin_log("create", "data", undef, \%in);
	}
elsif ($in{'cancel'} || $in{'new'}) {
	undef($in{'row'});
	}

$desc = &text('table_header', "<tt>$in{'table'}</tt>", "<tt>$in{'db'}</tt>");
&ui_print_header($desc, $text{'view_title'}, "", "view_table");

foreach $t (@str) {
	$has_blob++ if (&is_blob($t));
	}
if (!$driver_handle && $config{'blob_mode'} && $has_blob) {
	print "<center><b>",&text('view_warn', "<tt>DBI</tt>",
				  "<tt>DBD::Pg</tt>"),"</b></center><p>\n";
	}

$d = &execute_sql_safe($in{'db'}, "select count(*) from $qt $search");
$total = $d->{'data'}->[0]->[0];
if ($in{'jump'} > 0) {
        $in{'start'} = int($in{'jump'} / $config{'perpage'}) *
                       $config{'perpage'};
        if ($in{'start'} >= $total) {
                $in{'start'} = $total - $config{'perpage'};
                $in{'start'} = int(($in{'start'} / $config{'perpage'}) + 1) *
                               $config{'perpage'};
                }
        }
else {
	$in{'start'} = int($in{'start'});
	}
if ($in{'new'} && $total > $config{'perpage'}) {
	# go to the last screen for adding a row
	$in{'start'} = $total - $config{'perpage'};
	$in{'start'} = int(($in{'start'} / $config{'perpage'}) + 1) *
		       $config{'perpage'};
	}
if ($in{'start'} || $total > $config{'perpage'}) {
	print "<center>\n";
	if ($in{'start'}) {
		printf "<a href='view_table.cgi?db=%s&table=%s&start=%s%s'>".
		       "<img src=/images/left.gif border=0 align=middle></a>\n",
			$in{'db'}, $in{'table'},
			$in{'start'} - $config{'perpage'},
			$searchargs;
		}
	print "<font size=+1>",&text('view_pos', $in{'start'}+1,
	      $in{'start'}+$config{'perpage'} > $total ? $total :
	      $in{'start'}+$config{'perpage'}, $total),"</font>\n";
	if ($in{'start'}+$config{'perpage'} < $total) {
		printf "<a href='view_table.cgi?db=%s&table=%s&start=%s%s'>".
		      "<img src=/images/right.gif border=0 align=middle></a>\n",
			$in{'db'}, $in{'table'},
			$in{'start'} + $config{'perpage'},
			$searchargs;
		}
	print "</center>\n";
	}

if ($in{'field'}) {
	# Show details of simple search
        print "<table width=100% cellspacing=0 cellpadding=0><tr>\n";
        print "<td><b>",&text('view_searchhead', "<tt>$in{'for'}</tt>",
                           "<tt>$in{'field'}</tt>"),"</b></td>\n";
        print "<td align=right><a href='view_table.cgi?db=$in{'db'}&",
              "table=$in{'table'}'>$text{'view_searchreset'}</a></td>\n";
        print "</tr></table>\n";
        }
elsif ($in{'advanced'}) {
	# Show details of advanced search
	print "<table width=100% cellspacing=0 cellpadding=0><tr>\n";
	print "<td><b>",&text('view_searchhead2', scalar(@adv)),"</b></td>\n";
	print "<td align=right><a href='view_table.cgi?db=$in{'db'}&",
	      "table=$in{'table'}'>$text{'view_searchreset'}</a></td>\n";
	print "</tr></table>\n";
	}

if ($config{'blob_mode'}) {
	print &ui_form_start("view_table.cgi", "form-data"),"\n";
	}
else {
	print &ui_form_start("view_table.cgi", "post"),"\n";
	}
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_hidden("table", $in{'table'}),"\n";
print &ui_hidden("start", $in{'start'}),"\n";
print $searchhids;
$check = !defined($in{'row'}) && !$in{'new'};
if ($total || $in{'new'}) {
	# Get the rows of data, and show the table header
	$d = &execute_sql_safe($in{'db'},
			  "select oid,* from $qt $search limit ".
			  "$config{'perpage'} offset $in{'start'}");
	@data = @{$d->{'data'}};
	@titles = @{$d->{'titles'}}; shift(@titles);
	print &select_all_link("row"),"\n";
	print &select_invert_link("row"),"<br>\n";
	print &ui_columns_start([
		$check ? ( "" ) : ( ),
		map { $_->{'field'} } @str
		], 100);
	@tds = $check ? ( "width=5" ) : ( );
	($has_blob) = grep { &is_blob($_) } @str;

	# Add an empty row for inserting
	$realrows = scalar(@data);
	if ($in{'new'}) {
		push(@data, [ "*", map { undef } @str ]);
		$row{"*"} = 1;
		}

	# Show the rows, some of which may be editable
	map { $row{$_}++ } split(/\0/, $in{'row'});
	$w = int(100 / scalar(@str));
	$w = 10 if ($w < 10);
	for($i=0; $i<@data; $i++) {
		local @d = @{$data[$i]};
		local $oid = shift(@d);
		if ($row{$oid} && ($config{'add_mode'} || $has_blob)) {
			# Show multi-line row editor
			$et = "<table border>\n";
			$et .= "<tr $tb> <td><b>$text{'view_field'}</b></td> ".
			      "<td><b>$text{'view_data'}</b></td> </tr>\n";
			for($j=0; $j<@d; $j++) {
				local $nm = $i == $realrows ? $j :
						"${oid}_$titles[$j]";
				$et .= "<tr $cb> <td><b>$titles[$j]</b></td> <td>";
				if ($config{'blob_mode'} &&
				    &is_blob($str[$j]) && $d[$j]) {
					# Show as keep/upload inputs
					$et .= &ui_radio($nm."_def", 1,
					    [ [ 1, $text{'view_keep'} ],
					      [ 0, $text{'view_set'} ] ])." ".
					  &ui_upload($nm);
					}
				elsif ($config{'blob_mode'} &&
				       &is_blob($str[$j])) {
					# Show upload input
					$et .= &ui_upload($nm);
					}
				elsif ($str[$j]->{'type'} =~ /\((\d+)\)/) {
					# Show as known-size text
					local $nw = $1 > 70 ? 70 : $1;
					$et .= &ui_textbox($nm, $d[$j], $nw);
					}
				elsif (&is_blob($str[$j])) {
					# Show as multiline text
					$et .= &ui_textarea($nm, $d[$j], 5, 70);
					}
				else {
					# Show as fixed-size text
					$et .= &ui_textbox($nm, $d[$j], 30);
					}
				$et .= "</td></tr>\n";
				}
			print &ui_hidden("row", $oid),"\n";
			$et .= "</table>";
			print &ui_columns_row([ $check ? ( "" ) : ( ), $et ],
					      [ @tds, "colspan=".scalar(@d) ] );
			}
		elsif ($row{$oid}) {
			# Show one-line row-editor
			local @cols;
			for($j=0; $j<@d; $j++) {
				local $l = $d[$j] =~ tr/\n/\n/;
				local $nm = $i == $realrows ? $j :
					"${oid}_$titles[$j]";
				if ($config{'blob_mode'} &&
				    &is_blob($str[$j])) {
					# Cannot edit this blob
					push(@cols, undef);
					}
				elsif ($str[$j]->{'type'} =~ /\((\d+)\)/) {
					# Show as known-size text
					local $nw = $1 > 70 ? 70 : $1;
					push(@cols,
					     &ui_textbox($nm, $d[$j], $nw));
					}
				elsif ($l) {
					# Show as multiline text
					$l++;
					push(@cols,
					     &ui_textarea($nm, $d[$j], $l, $w));
					}
				else {
					# Show as known size text
					push(@cols,
					     &ui_textbox($nm, $d[$j], $w));
					}
				}
			print &ui_hidden("row", $oid),"\n";
			print &ui_columns_row([ $check ? ( "" ) : ( ), @cols ],
					      \@tds);
			}
		else {
			# Show contents of row
			local @cols;
			local $j = 0;
			foreach $c (@d) {
				if ($config{'blob_mode'} &&
                                    &is_blob($str[$j]) && $c ne '') {
					# Show download link for blob
                                        push(@cols, "<a href='download.cgi?db=$in{'db'}&table=$in{'table'}&row=$oid&field=".&urlize($str[$j]->{'field'})."'>$text{'view_download'}</a>");
                                        }
                                else {
					# Just show text (up to limit)
					if ($config{'max_text'} &&
					    length($c) > $config{'max_text'}) {
						$c = substr($c, 0,
						  $config{'max_text'})." ...";
						}
					push(@cols, &html_escape($c));
					}
				$j++;
				}
			if ($check) {
				print &ui_checked_columns_row(\@cols, \@tds,
							      "row", $oid);
				}
			else {
				print &ui_columns_row(\@cols, \@tds);
				}
			}
		print "</tr>\n";
		}
	print &ui_columns_end();
	if ($check) {
		print &select_all_link("row"),"\n";
		print &select_invert_link("row"),"<br>\n";
		}
	}
else {
	print "<b>$text{'view_none'}</b> <p>\n";
	}

# Show buttons to edit / delete rows
if (!$check) {
	if ($in{'new'}) {
		print &ui_form_end([ [ "savenew", $text{'save'} ],
				     [ "cancel", $text{'cancel'} ] ]);
		}
	else {
		print &ui_form_end([ [ "save", $text{'save'} ],
				     [ "cancel", $text{'cancel'} ] ]);
		}
	}
elsif ($total) {
	print &ui_form_end([ [ "edit", $text{'view_edit'} ],
			     [ "new", $text{'view_new'} ],
			     [ "delete", $text{'view_delete'} ] ]);
	}
else {
	print &ui_form_end([ [ "new", $text{'view_new'} ] ]);
	}

if (!$in{'field'} && $total > $config{'perpage'} || 1) {
	print "<hr>\n";
	print "<table width=100%><tr>\n";
	print "<form action=view_table.cgi>\n";
	print "<input type=hidden name=search value=1>\n";
	print &ui_hidden("db", $in{'db'});
	print &ui_hidden("table", $in{'table'});
	$sel = &ui_select("field", undef,
			[ map { [ $_->{'field'}, $_->{'field'} ] } @str ]);
	$match = &ui_select("match", 0,
			[ map { [ $_, $text{'view_match'.$_} ] } (0.. 3) ]);
	print "<td>",&text('view_search2', "<input name=for size=20>", $sel,
			   $match);
	print "&nbsp;&nbsp;",
	      "<input type=submit value='$text{'view_searchok'}'></td>\n";
	print "</form>\n";

	print "<form action=view_table.cgi>\n";
	print &ui_hidden("db", $in{'db'});
	print &ui_hidden("table", $in{'table'});
	print "<td align=right><input type=submit value='$text{'view_jump'}'> ";
	print "<input name=jump size=6></td></form>\n";

	print "</tr><tr>\n";

	print "<form action=search_form.cgi>\n";
	print &ui_hidden("db", $in{'db'});
	print &ui_hidden("table", $in{'table'});
	print "<td><input type=submit value='$text{'view_adv'}'></td>\n";
	print "</form>\n";

	print "</tr> </table>\n";
	}

&ui_print_footer("edit_table.cgi?db=$in{'db'}&table=$in{'table'}",$text{'table_return'},
	"edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	"", $text{'index_return'});

# make_like(mode, for, field)
sub make_like
{
local ($match, $for, $field) = @_;
local ($finfo) = grep { $_->{'field'} eq $field } @str;
local $bool = $finfo->{'type'} eq 'bool';
local $bit = $finfo->{'type'} =~ /^bit/;
return $bool && $match <= 1 ? "= $for" :
       $bool && $match > 1 ? "!= $for" :
       $bit && $match <= 1 ? "= b'$for'" :
       $bit && $match > 1 ? "!= b'$for'" :
       $match == 0 ? "like '%$for%'" :
       $match == 1 ? "like '$for'" :
       $match == 2 ? "not like '%$for%'" :
       $match == 3 ? "not like '$for'" : " = ''";
}

