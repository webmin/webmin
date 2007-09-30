
do '../web-lib.pl';
&init_config();

sub acl_security_form
{
print "<tr> <td><b>$text{'acl_link'}</b></td>\n";
printf "<td colspan=3><input name=link size=50 value='%s'></td> </tr>\n",
	$_[0]->{'link'};
}

sub acl_security_save
{
$in{'link'} =~ /\S/ || &error($text{'acl_elink'});
$_[0]->{'link'} = $in{'link'};
}

