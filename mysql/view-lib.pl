# Functions used by view_table.cgi and siblings

# get_search_args(&in)
# Returns the search SQL, search URL arguments and search hidden fields
sub get_search_args
{
local %in = %{$_[0]};
local ($search, $searchhids, $searchargs, @adv);
if ($in{'field'}) {
	# A simple search
	$search = "where ".&quotestr($in{'field'})." ".
		   &make_like($in{'match'}, $in{'for'});
	$searchargs = "&field=".&urlize($in{'field'}).
		      "&for=".&urlize($in{'for'}).
		      "&match=".&urlize($in{'match'});
	$searchhids = &ui_hidden("field", $in{'field'})."\n".
		      &ui_hidden("for", $in{'for'})."\n".
		      &ui_hidden("match", $in{'match'})."\n";
	}
elsif ($in{'advanced'}) {
	# An advanced search
	for(my $i=0; defined($in{"field_$i"}); $i++) {
		if ($in{"field_$i"}) {
			push(@adv, &quotestr($in{"field_$i"})." ".
				   &make_like($in{"match_$i"}, $in{"for_$i"}));
			$searchargs .= "&field_$i=".&urlize($in{"field_$i"}).
				       "&for_$i=".&urlize($in{"for_$i"}).
				       "&match_$i=".&urlize($in{"match_$i"});
			$searchhids .=
				&ui_hidden("field_$i", $in{"field_$i"})."\n".
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
return ($search, $searchhids, $searchargs, scalar(@adv));
}

# get_search_limit(&in)
# Build limiting expression
sub get_search_limit
{
local %in = %{$_[0]};
$in{'start'} ||= 0;
if ($module_name eq "mysql") {
	return "limit $in{'start'},$displayconfig{'perpage'}";
	}
else {
	return "limit $displayconfig{'perpage'} offset $in{'start'}";
	}
}

# get_search_limit(&in)
# Returns an SQL expression for sorting, hidden fields for the current sort order, and
# URL args for the current order
sub get_search_sort
{
local %in = %{$_[0]};
if ($in{'sortfield'}) {
	local ($sort, $sorthids, $sortargs);
	$sort = "order by ".&quotestr($in{'sortfield'})." ".($in{'sortdir'} ? "asc" : "desc");
	$sorthids = &ui_hidden("sortfield", $in{'sortfield'})."\n".
		    &ui_hidden("sortdir", $in{'sortdir'})."\n";
	$sortargs = "&sortfield=".&urlize($in{'sortfield'}).
		    "&sortdir=$in{'sortdir'}";
	return ($sort, $sorthids, $sortargs);
	}
else {
	return ( undef, undef, undef );
	}
}

# make_like(mode, for)
sub make_like
{
local ($match, $for) = @_;
local $qu = $module_name eq "mysql" ? '"' : "'";
return $match == 0 ? "like $qu%$for%$qu" :
       $match == 1 ? "like $qu$for$qu" :
       $match == 2 ? "not like $qu%$for%$qu" :
       $match == 3 ? "not like $qu$for$qu" :
       $match == 4 ? "> $for" :
       $match == 5 ? "< $for" :
		     " = \"\"";
}

1;

