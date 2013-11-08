
if (!defined($services_file)) {
	do 'itsecur-lib.pl';
	}

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
# Work out which features can be edited and which can be read
local (@edit, @read);
if (defined($_[0]->{'edit'})) {
	if ($_[0]->{'edit'}) {
		@edit = @read = split(/\s+/, $_[0]->{'features'});
		}
	else {
		@read = split(/\s+/, $_[0]->{'features'});
		}
	}
else {
	@edit = split(/\s+/, $_[0]->{'features'});
	@read = split(/\s+/, $_[0]->{'rfeatures'});
	}

local $w;
foreach $w ([ \@edit, "features", "all" ],
	    [ \@read, "rfeatures", "rall" ]) {
	local %can = map { $_, 1 } @{$w->[0]};
	print "<tr> <td valign=top><b>",$text{'acl_'.$w->[1]},
	      "</b></td> <td>\n";
	printf "<input type=radio name=$w->[2] value=1 %s> %s\n",
		$can{"*"} ? "checked" : "", $text{'acl_all'};
	printf "<input type=radio name=$w->[2] value=0 %s> %s<br>\n",
		$can{"*"} ? "" : "checked", $text{'acl_sel'};
	printf "<select name=$w->[1] multiple size=%d>\n",
		scalar(@opts);
	foreach $o (@opts, 'apply', 'bootup') {
		printf "<option value=%s %s>%s</option>\n",
			$o, $can{$o} ? "selected" : "",
			$text{"acl_".$o} || $text{$o."_title"};
		}
	print "</select></td> </tr>\n";
	}
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'features'} = $in{'all'} ? "*" :
			join(" ", split(/\0/, $in{'features'}));
$_[0]->{'rfeatures'} = $in{'rall'} ? "*" :
			join(" ", split(/\0/, $in{'rfeatures'}));
delete($_[0]->{'edit'});
}

1;

