# mod_autoindex.pl
# Defines editors automatic index generation

sub mod_autoindex_directives
{
local($rv, $all); $all = 'virtual directory htaccess';
$rv = [ [ 'AddIcon AddIconByType AddIconByEncoding', 1, 12, $all, 1.3, 1 ],
        [ 'DefaultIcon', 0, 12, $all, 1.3, 5 ],
        [ 'AddAlt AddAltByType AddAltByEncoding', 1, 12, $all, 1.3 ],
        [ 'AddDescription', 1, 12, $all, 1.3 ],
        [ 'IndexOptions FancyIndexing', 0, 12, $all, 1.3, 10 ],
        [ 'HeaderName', 0, 12, $all, 1.3, 4 ],
        [ 'ReadmeName', 0, 12, $all, 1.3, 3 ],
        [ 'IndexIgnore', 1, 12, $all, 1.3, 6 ],
	[ 'IndexOrderDefault', 0, 12, $all, 1.304, 2 ] ];
return &make_directives($rv, $_[0], "mod_autoindex");
}

sub edit_IndexOrderDefault
{
local $rv = sprintf
	"<input type=radio name=IndexOrderDefault_def value=1 %s> $text{'mod_autoindex_default'}\n",
	$_[0] ? "" : "checked";
$rv .= sprintf "<input type=radio name=IndexOrderDefault_def value=0 %s>\n",
	$_[0] ? "checked" : "";
$rv .= "<select name=IndexOrderDefault_asc>\n";
$rv .= sprintf "<option value=Ascending %s>$text{'mod_autoindex_asc'}</option>\n",
		$_[0]->{'words'}->[0] eq "Ascending" ? "selected" : "";
$rv .= sprintf "<option value=Descending %s>$text{'mod_autoindex_descend'}</option>\n",
		$_[0]->{'words'}->[0] eq "Descending" ? "selected" : "";
$rv .= "</select>\n";
$rv .= "<select name=IndexOrderDefault_what>\n";
$rv .= sprintf "<option value=Name %s>$text{'mod_autoindex_name'}</option>\n",
		$_[0]->{'words'}->[1] eq "Name" ? "selected" : "";
$rv .= sprintf "<option value=Date %s>$text{'mod_autoindex_date'}\n",
		$_[0]->{'words'}->[1] eq "Date" ? "selected" : "",
		"</option>";
$rv .= sprintf "<option value=Size %s>$text{'mod_autoindex_size'}</option>\n",
		$_[0]->{'words'}->[1] eq "Size" ? "selected" : "";
$rv .= sprintf "<option value=Description %s>$text{'mod_autoindex_desc'}</option>\n",
		$_[0]->{'words'}->[1] eq "Description" ? "selected" : "";
$rv .= "</select>\n";
return (2, "$text{'mod_autoindex_sort'}", $rv);
}
sub save_IndexOrderDefault
{
if ($in{'IndexOrderDefault_def'}) { return ( [ ] ); }
else { return ( [ "$in{'IndexOrderDefault_asc'} $in{'IndexOrderDefault_what'}" ] ); }
}

require 'autoindex.pl';

1;

