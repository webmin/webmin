
require 'pptp-server-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the pptp-server module
sub acl_security_form
{
print "<tr><td valign=top><b>$text{'acl_conf'}</b></td>\n";
print "<td valign=top>\n";
printf "<input type=radio name=conf value=1 %s> $text{'yes'}\n",
          $_[0]->{'conf'} ? "checked" : "";
printf "<input type=radio name=conf value=0 %s> $text{'no'}</td></tr>\n",
        $_[0]->{'conf'} ? "" : "checked";

print "<tr><td valign=top><b>$text{'acl_options'}</b></td>\n";
print "<td valign=top>\n";
printf "<input type=radio name=options value=1 %s> $text{'yes'}\n",
          $_[0]->{'options'} ? "checked" : "";
printf "<input type=radio name=options value=0 %s> $text{'no'}</td></tr>\n",
        $_[0]->{'options'} ? "" : "checked";

print "<tr><td valign=top><b>$text{'acl_secrets'}</b></td>\n";
print "<td valign=top>\n";
printf "<input type=radio name=secrets value=1 %s> $text{'yes'}\n",
          $_[0]->{'secrets'} ? "checked" : "";
printf "<input type=radio name=secrets value=0 %s> $text{'no'}</td></tr>\n",
        $_[0]->{'secrets'} ? "" : "checked";

print "<tr><td valign=top><b>$text{'acl_conns'}</b></td>\n";
print "<td valign=top>\n";
printf "<input type=radio name=conns value=1 %s> $text{'yes'}\n",
          $_[0]->{'conns'} ? "checked" : "";
printf "<input type=radio name=conns value=0 %s> $text{'no'}</td></tr>\n",
        $_[0]->{'conns'} ? "" : "checked";

print "<tr><td valign=top><b>$text{'acl_stop'}</b></td>\n";
print "<td valign=top>\n";
printf "<input type=radio name=stop value=1 %s> $text{'yes'}\n",
          $_[0]->{'stop'} ? "checked" : "";
printf "<input type=radio name=stop value=0 %s> $text{'no'}</td></tr>\n",
        $_[0]->{'stop'} ? "" : "checked";

print "<tr><td valign=top><b>$text{'acl_apply'}</b></td>\n";
print "<td valign=top>\n";
printf "<input type=radio name=apply value=1 %s> $text{'yes'}\n",
          $_[0]->{'apply'} ? "checked" : "";
printf "<input type=radio name=apply value=0 %s> $text{'no'}</td></tr>\n",
        $_[0]->{'apply'} ? "" : "checked";
}

# acl_security_save(&options)
# Parse the form for security options for the pptp-server module
sub acl_security_save
{
$_[0]->{'conf'} = $in{'conf'};
$_[0]->{'options'} = $in{'options'};
$_[0]->{'secrets'} = $in{'secrets'};
$_[0]->{'conns'} = $in{'conns'};
$_[0]->{'stop'} = $in{'stop'};
$_[0]->{'apply'} = $in{'apply'};
}
