
do 'shorewall6-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_nochange'}</b></td> <td>\n";
printf "<input type=radio name=nochange value=0 %s> $text{'yes'}\n",
	$_[0]->{'nochange'} ? '' : 'checked';
printf "<input type=radio name=nochange value=1 %s> $text{'no'}</td>\n",
	$_[0]->{'nochange'} ? 'checked' : '';

print "</tr>\n";

print "<tr> <td valign=top><b>$text{'acl_files'}</b></td> <td>\n";
print &ui_radio("files_def", $_[0]->{'files'} eq '*' ? 1 : 0,
		[ [ 1, $text{'acl_all'} ], [ 0, $text{'acl_sel'} ] ]),"<br>\n";
print &ui_select("files", [ split(/\s+/, $_[0]->{'files'}) ],
		 [ map { [ $_, $text{$_."_title"}." ($_)" ] }
		       @shorewall6_files ], 5, 1);
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'nochange'} = $in{'nochange'};
$_[0]->{'files'} = $in{'files_def'} ? "*"
				    : join(" ", split(/\0/, $in{'files'}));
}

