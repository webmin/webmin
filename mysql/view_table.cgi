#!/usr/local/bin/perl
# view_table.cgi
# Display all data in some table

if (-r 'mysql-lib.pl') {
	require './mysql-lib.pl';
	}
else {
	require './postgresql-lib.pl';
	}

if ($config{'charset'}) {
	$main::force_charset = $config{'charset'};
	}
if ($ENV{'CONTENT_TYPE'} !~ /boundary=/) {
	&ReadParse();
	}
else {
	&ReadParseMime();
	}
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
@str = &table_structure($in{'db'}, $in{'table'});
foreach $s (@str) {
	$keyed++ if ($s->{'key'} eq 'PRI');
	}
if (!$keyed && $module_name eq "postgresql") {
	# Can use oid as key
	eval { $main::error_must_die = 1;
	       $d = &execute_sql($in{'db'}, "select oid from ".
					    &quote_table($in{'table'}).
					    " where 0 = 1"); };
	if (!$@) {
		# Has an OID, so use it
		$use_oids = 1;
		$keyed = 1;
		}
	}

# Get search SQL
($search, $searchhids, $searchargs, $advcount) = &get_search_args(\%in);

# Work out start position
$d = &execute_sql_safe($in{'db'},
	"select count(*) from ".&quote_table($in{'table'})." ".$search);
$total = int($d->{'data'}->[0]->[0]);
if ($in{'jump'} > 0) {
	$in{'start'} = int($in{'jump'} / $displayconfig{'perpage'}) *
		       $displayconfig{'perpage'};
	if ($in{'start'} >= $total) {
		$in{'start'} = $total - $displayconfig{'perpage'};
		$in{'start'} = int(($in{'start'} / $displayconfig{'perpage'}) + 1) *
			       $displayconfig{'perpage'};
		}
	}
else {
	$in{'start'} = int($in{'start'});
	}
if ($in{'new'} && $total > $displayconfig{'perpage'}) {
	# go to the last screen for adding a row
	$in{'start'} = $total - $displayconfig{'perpage'};
	$in{'start'} = int(($in{'start'} / $displayconfig{'perpage'}) + 1) *
		       $displayconfig{'perpage'};
	}

# Get limiting and sorting SQL
$limitsql = &get_search_limit(\%in);
($sortsql, $sorthids, $sortargs) = &get_search_sort(\%in);

# Work out where clause for rows we are operating on
$where_select = "select ".($use_oids ? "oid" : "*").
	" from ".&quote_table($in{'table'})." $search $sortsql $limitsql";

if ($in{'delete'}) {
	# Deleting selected rows
	$d = &execute_sql($in{'db'}, $where_select);
	@t = map { $_->{'field'} } @str;
	$count = 0;
	foreach $r (split(/\0/, $in{'row'})) {
		local @where;
		local @r = @{$d->{'data'}->[$r]};
		if ($use_oids) {
			# Where clause just uses OID
			push(@where, "oid = $r[0]");
			}
		else {
			# Where clause uses keys
			for($i=0; $i<@t; $i++) {
				if ($str[$i]->{'key'} eq 'PRI') {
					if ($r[$i] eq 'NULL') {
						push(@where, &quotestr($t[$i]).
							     " is null");
						}
					else {
						$r[$i] =~ s/'/''/g;
						push(@where, &quotestr($t[$i]).
							     " = '$r[$i]'");
						}
					}
				}
			}
		&execute_sql_logged($in{'db'},
				    "delete from ".&quote_table($in{'table'}).
				    " where ".join(" and ", @where));
		$count++;
		}
	&webmin_log("delete", "data", $count, \%in);
	&redirect("view_table.cgi?db=$in{'db'}&".
		  "table=".&urlize($in{'table'})."&start=$in{'start'}".
		  $searchargs.$sortargs);
	}
elsif ($in{'save'}) {
	# Update edited rows
	$d = &execute_sql($in{'db'}, $where_select);
	@t = map { $_->{'field'} } @str;
	$count = 0;
	for($j=0; $j<$displayconfig{'perpage'}; $j++) {
		next if (!defined($in{"${j}_$t[0]"}));
		local (@where, @set);
		local @r = @{$d->{'data'}->[$j]};
		local @params;
		if ($use_oids) {
			# Where clause just uses OID
			push(@where, "oid = $r[0]");
			}
		for($i=0; $i<@t; $i++) {
			if (!$use_oids) {
				# Where clause uses keys
				if ($str[$i]->{'key'} eq 'PRI') {
					if ($r[$i] eq 'NULL') {
						push(@where, &quotestr($t[$i]).
							     " is null");
						}
					else {
						$r[$i] =~ s/'/''/g;
						push(@where, &quotestr($t[$i]).
							     " = '$r[$i]'");
						}
					}
				}
			local $ij = $in{"${j}_$t[$i]"};
			local $ijnull = $in{"${j}_$t[$i]_null"};
			local $ijdef = $in{"${j}_$t[$i]_def"};
			next if ($ijdef || !defined($ij));
			if (!$displayconfig{'blob_mode'} || !&is_blob($str[$i])) {
				$ij =~ s/\r//g;
				}
			push(@set, &quotestr($t[$i])." = ?");
			push(@params, $ijnull ? undef : $ij);
			}
		&execute_sql_logged($in{'db'},
			    "update ".&quote_table($in{'table'})." set ".
			    join(" , ", @set)." where ".
			    join(" and ", @where), @params);
		$count++;
		}
	&webmin_log("modify", "data", $count, \%in);
	&redirect("view_table.cgi?db=$in{'db'}&".
		  "table=".&urlize($in{'table'})."&start=$in{'start'}".
		  $searchargs.$sortargs);
	}
elsif ($in{'savenew'}) {
	# Adding a new row
	for($j=0; $j<@str; $j++) {
		if (!$displayconfig{'blob_mode'} || !&is_blob($str[$j])) {
			$in{$j} =~ s/\r//g;
			}
		push(@set, $in{$j."_null"} ? undef : $in{$j});
		}
	&execute_sql_logged($in{'db'}, "insert into ".&quote_table($in{'table'}).
		    " values (".join(" , ", map { "?" } @set).")", @set);
	&redirect("view_table.cgi?db=$in{'db'}&".
		  "table=".&urlize($in{'table'})."&start=$in{'start'}".
		  $searchargs.$sortargs);
	&webmin_log("create", "data", undef, \%in);
	}
elsif ($in{'cancel'} || $in{'new'}) {
	undef($in{'row'});
	}

$desc = &text('table_header', "<tt>$in{'table'}</tt>", "<tt>$in{'db'}</tt>");
&ui_print_header($desc, $text{'view_title'}, "");

if ($in{'start'} || $total > $displayconfig{'perpage'}) {
	print "<center>\n";
	if ($in{'start'}) {
		printf "<a href='view_table.cgi?db=%s&table=%s&start=%s%s%s'>".
		     "<img src=../images/left.gif border=0 align=middle></a>\n",
		     $in{'db'}, $in{'table'},
		     $in{'start'} - $displayconfig{'perpage'},
		     $searchargs, $sortargs;
		}
	print "<font size=+1>",&text('view_pos', $in{'start'}+1,
	      $in{'start'}+$displayconfig{'perpage'} > $total ? $total :
	      $in{'start'}+$displayconfig{'perpage'}, $total),"</font>\n";
	if ($in{'start'}+$displayconfig{'perpage'} < $total) {
		printf "<a href='view_table.cgi?db=%s&table=%s&start=%s%s%s'>".
		     "<img src=../images/right.gif border=0 align=middle></a> ",
		     $in{'db'}, $in{'table'},
		     $in{'start'} + $displayconfig{'perpage'},
		     $searchargs, $sortargs;
		}
	print "</center>\n";
	}

print "<table width=100% cellspacing=0 cellpadding=0>\n";

if ($in{'field'}) {
	# Show details of simple search
	my $msg = $in{'match'} == 2 || $in{'match'} == 3 ?
			'view_searchheadnot' : 'view_searchhead';
	print "<tr> <td><b>",&text($msg, "<tt>$in{'for'}</tt>",
			   "<tt>$in{'field'}</tt>"),"</b></td>\n";
	print "<td align=right><a href='view_table.cgi?db=$in{'db'}&",
	      "table=$in{'table'}$sortargs'>$text{'view_searchreset'}</a></td> </tr>\n";
	}
elsif ($in{'advanced'}) {
	# Show details of advanced search
	print "<tr> <td><b>",&text('view_searchhead2', $advcount),"</b></td>\n";
	print "<td align=right><a href='view_table.cgi?db=$in{'db'}&",
	      "table=$in{'table'}$sortargs'>$text{'view_searchreset'}</a></td> </tr>\n";
	}
if ($in{'sortfield'}) {
	# Show current sort order
	print "<tr> <td><b>",&text($in{'sortdir'} ? 'view_sorthead2' : 'view_sorthead1',
			      "<tt>$in{'sortfield'}</tt>"),"</b></td>\n";
	print "<td align=right><a href='view_table.cgi?db=$in{'db'}&",
	      "table=$in{'table'}$searchargs'>$text{'view_sortreset'}</a></td> </tr>\n";
	}

print "</table>\n";

if ($displayconfig{'blob_mode'}) {
	print &ui_form_start("view_table.cgi", "form-data");
	}
else {
	print &ui_form_start("view_table.cgi", "post");
	}
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_hidden("table", $in{'table'}),"\n";
print &ui_hidden("start", $in{'start'}),"\n";
print $searchhids;
print $sorthids;
$check = !defined($in{'row'}) && !$in{'new'} && $keyed;
if ($total || $in{'new'}) {
	# Get the rows of data, and show the table header
	$sql = "select * from ".&quote_table($in{'table'}).
	       " $search $sortsql $limitsql";
	$d = &execute_sql_safe($in{'db'}, $sql);
	@data = @{$d->{'data'}};
	@tds = $check ? ( "width=5" ) : ( );
	($has_blob) = grep { &is_blob($_) } @str;

	@rowlinks = $check ? ( &select_all_link("row"),
			       &select_invert_link("row") ) : ( );
	print &ui_links_row(\@rowlinks);
	print &ui_columns_start([
		$check ? ( "" ) : ( ),
		map { &column_sort_link($_->{'field'}) } @str
		], 100, 0, \@tds);

	# Add an empty row for inserting
	$realrows = scalar(@data);
	if ($in{'new'}) {
		push(@data, [ map { $_->{'default'} eq 'NULL' ? '' :
				    $_->{'default'} eq 'CURRENT_TIMESTAMP' ? '':
				      $_->{'default'} } @str ]);
		$row{$realrows} = 1;
		}

	# Show the rows, some of which may be editable
	map { $row{$_}++ } split(/\0/, $in{'row'});
	$w = int(100 / scalar(@str));
	$w = 10 if ($w < 10);
	for($i=0; $i<@data; $i++) {
		local @d = map { $_ eq "NULL" ? undef : $_ } @{$data[$i]};
		if ($row{$i} && ($displayconfig{'add_mode'} || $has_blob)) {
			# Show multi-line row editor
			$et = "<table border>\n";
			$et .= "<tr $tb> <td><b>$text{'view_field'}</b></td> ".
			      "<td><b>$text{'view_data'}</b></td> </tr>\n";
			for($j=0; $j<@str; $j++) {
				local $nm = $i == $realrows ? $j :
						"${i}_$str[$j]->{'field'}";
				$et .= "<tr $cb> <td><b>$str[$j]->{'field'}</b></td> <td>\n";
				if ($displayconfig{'blob_mode'} &&
				    &is_blob($str[$j]) && $d[$j]) {
					# Show as keep/upload inputs
					$et .= &ui_radio($nm."_def", 1,
					    [ [ 1, $text{'view_keep'} ],
					      [ 0, $text{'view_set'} ] ])." ".
					  &ui_upload($nm);
					}
				elsif ($displayconfig{'blob_mode'} &&
				       &is_blob($str[$j])) {
					# Show upload input
					$et .= &ui_upload($nm);
					}
				elsif ($str[$j]->{'type'} =~ /^enum\((.*)\)$/) {
					# Show as enum list
					$et .= &ui_select($nm, $d[$j],
					    [ [ "", "&nbsp;" ],
					      map { [ $_ ] } &split_enum($1) ],
					    1, 0, 1);
					}
				elsif ($str[$j]->{'type'} =~ /\((\d+)\)/) {
					# Show as known-size text
					if ($1 > 255) {
						# Too big, use text area
						$et .= &ui_textarea(
							$nm, $d[$j], 5, 70);
						}
					else {
						# Text box
						local $nw = $1 > 70 ? 70 : $1;
						$et .= &ui_textbox(
							$nm, $d[$j], $nw);
						}
					}
				elsif (&is_blob($str[$j])) {
					# Show as multiline text
					$et .= &ui_textarea($nm, $d[$j], 5, 70);
					}
				else {
					# Show as fixed-size text
					$et .= &ui_textbox($nm, $d[$j], 30);
					}
				if ($str[$j]->{'null'} eq 'YES') {
					# Checkbox for null value, if allowed
					$et .= "&nbsp;".&ui_checkbox($nm."_null", 1,
						"NULL?", $i != $realrows && !defined($d[$j]));
					}
				$et .= "</td></tr>\n";
				}
			$et .= "</table>";
			print &ui_columns_row([ $check ? ( "" ) : ( ), $et ],
					      [ @tds, "colspan=".scalar(@d) ] );
			}
		elsif ($row{$i}) {
			# Show one-line row-editor
			local @cols;
			for($j=0; $j<@d; $j++) {
				local $l = $d[$j] =~ tr/\n/\n/;
				local $nm = $i == $realrows ? $j :
						"${i}_$d->{'titles'}->[$j]";
				local $ui;
				if ($displayconfig{'blob_mode'} &&
				    &is_blob($str[$j])) {
					# Cannot edit this blob
					$ui = "";
					}
				elsif ($str[$j]->{'type'} =~ /^enum\((.*)\)$/) {
					# Show as enum list
					$ui = &ui_select($nm, $d[$j],
					    [ [ "", "&nbsp;" ],
					      map { [ $_ ] } &split_enum($1) ],
					    1, 0, 1);
					}
				elsif ($str[$j]->{'type'} =~ /\((\d+)\)/) {
					# Show as known-size text
					local $nw = $1 > 70 ? 70 : $1;
					$ui = &ui_textbox($nm, $d[$j], $nw);
					}
				elsif ($l) {
					# Show as multiline text
					$l++;
					$ui = &ui_textarea($nm, $d[$j], $l, $w);
					}
				else {
					# Show as known size text
					$ui = &ui_textbox($nm, $d[$j], $w);
					}
				if ($ui && $str[$j]->{'null'} eq 'YES') {
					# Checkbox for null value, if allowed
					$ui .= "&nbsp;".&ui_checkbox($nm."_null", 1,
						"NULL?", $i != $realrows && !defined($d[$j]));
					}
				push(@cols, $ui);
				}
			print &ui_columns_row([ $check ? ( "" ) : ( ), @cols ],
					      \@tds);
			}
		else {
			# Show row contents
			local @cols;
			local $j = 0;
			foreach $c (@d) {
				if (!defined($c)) {
					# Show as null
					push(@cols, "<i>NULL</i>");
					}
				elsif ($displayconfig{'blob_mode'} &&
				       &is_blob($str[$j]) && $c ne '') {
					# Show download link for blob
					push(@cols, &ui_link(
						"@{[&get_webprefix()]}/".
						  "$module_name/download.cgi?".
						  "db=$in{'db'}&table=$in{'table'}".
						  "&start=$in{'start'}".
						  $searchargs.$sortargs.
						  "&row=$i&col=$j",
						$text{'view_download'}));
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
							      "row", $i);
				}
			else {
				print &ui_columns_row(\@cols, \@tds);
				}
			}
		}
	print &ui_columns_end();
	print &ui_links_row(\@rowlinks);
	print &text('view_sqlrun', "<tt>".&html_escape($sql)."</tt>")."<p>\n";
	}
else {
	print "<b>$text{'view_none'}</b> <p>\n";
	}

# Show buttons to edit / delete rows
if (!$keyed) {
	print "<b>$text{'view_nokey'}</b><p>\n";
	print &ui_form_end();
	}
elsif (!$check) {
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
			     [ "delete", $text{'view_delete'} ],
			     [ "refresh", $text{'view_refresh'} ] ]);
	}
else {
	print &ui_form_end([ [ "new", $text{'view_new'} ] ]);
	}

if (!$in{'field'} && $total > $displayconfig{'perpage'}) {
	# Show search and jump buttons
	print &ui_hr();

	print &ui_form_start("view_table.cgi");
	print &ui_hidden("search", 1);
	print &ui_hidden("db", $in{'db'});
	print &ui_hidden("table", $in{'table'});
	$sel = &ui_select("field", undef,
			[ map { [ $_->{'field'}, $_->{'field'} ] } @str ]);
	$match = &ui_select("match", 0,
			[ map { [ $_, $text{'view_match'.$_} ] } (0.. 5) ]);
	print &text('view_search2', &ui_textbox("for", "", 20),
			  $sel, $match),"\n";
	print &ui_submit($text{'view_searchok'});
	print &ui_form_end();

	# Advanced search form
	print &ui_form_start("search_form.cgi");
	print &ui_hidden("db", $in{'db'});
	print &ui_hidden("table", $in{'table'});
	print &ui_submit($text{'view_adv'});
	print &ui_form_end();
	print "<p>\n";

	# Jump to a row
	print &ui_form_start("view_table.cgi");
	print "<b>$text{'view_jump'}</b>\n";
	print &ui_hidden("db", $in{'db'});
	print &ui_hidden("table", $in{'table'});
	print &ui_textbox("jump", "", 6);
	print &ui_submit($text{'view_go'});
	print &ui_form_end();
	}

if ($access{'edonly'}) {
	&ui_print_footer("edit_dbase.cgi?db=$in{'db'}",$text{'dbase_return'},
		 &get_databases_return_link($in{'db'}), $text{'index_return'});
	}
else {
	&ui_print_footer("edit_table.cgi?db=$in{'db'}&table=".
			 &urlize($in{'table'}),
			$text{'table_return'},
			"edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
			&get_databases_return_link($in{'db'}), $text{'index_return'});
	}

# column_sort_link(name)
# Returns HTML for a link to switch sorting mode
sub column_sort_link
{
local ($field) = @_;
local $dir = $in{'sortfield'} eq $field ? !$in{'sortdir'} : 0;
local $img = $in{'sortfield'} eq $field && $dir ? "sortascgrey.gif" :
	     $in{'sortfield'} eq $field && !$dir ? "sortdescgrey.gif" :
	     $dir ? "sortasc.gif" : "sortdesc.gif";
return "<a href='view_table.cgi?db=$in{'db'}&table=".
       &urlize($in{'table'})."&start=$in{'start'}&sortfield=$field&sortdir=$dir$searchargs'>".
       "<b>$field</b><img valign=middle src=../images/$img border=0>";
}

