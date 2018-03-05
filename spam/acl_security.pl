
require 'spam-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the spam module
sub acl_security_form
{
# Allowed features
print "<tr> <td valign=top><b>$text{'acl_avail'}</b></td>\n";
print "<td><select name=avail rows=6 multiple>\n";
local %avail = map { $_, 1 } split(/,/, $_[0]->{'avail'});
foreach $a ('white', 'score', 'report', 'user', 'header', 'priv', 'setup', 'procmail',
	    'amavisd', 'db', 'awl', 'manual') {
	printf "<option value=%s %s>%s</option>\n",
		$a, $avail{$a} ? "selected" : "", $text{$a."_title"};
	}
print "</select></td> </tr>\n";

# Config file to edit
print "<tr> <td><b>$text{'acl_file'}</b></td>\n";
print "<td>",&ui_opt_textbox("file", $_[0]->{'file'}, 40, $text{'acl_filedef'}),
      "</td> </tr>\n";

# Allowed auto-whitelist users
print "<tr> <td><b>$text{'acl_awl'}</b></td>\n";
print "<td>",&ui_radio("awl_mode", $_[0]->{'awl_groups'} ? 2 :
				    $_[0]->{'awl_users'} ? 1 : 0,
	[ [ 0, $text{'acl_awl0'}."<br>\n" ],
	  [ 1, &text('acl_awl1',
		&ui_textbox("awl_users", $_[0]->{'awl_users'}, 40).
		&user_chooser_button("awl_users", 1))."<br>\n" ],
	  [ 2, &text('acl_awl2',
		&ui_textbox("awl_groups", $_[0]->{'awl_groups'}, 40).
		&group_chooser_button("awl_users", 1))."<br>\n" ],
	]),"</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the cron module
sub acl_security_save
{
$_[0]->{'avail'} = join(",", split(/\0/, $in{'avail'}));
$_[0]->{'file'} = $in{'file_def'} ? undef : $in{'file'};
delete($_[0]->{'awl_users'});
delete($_[0]->{'awl_groups'});
if ($in{'awl_mode'} == 1) {
	$_[0]->{'awl_users'} = $in{'awl_users'};
	}
elsif ($in{'awl_mode'} == 2) {
	$_[0]->{'awl_groups'} = $in{'awl_groups'};
	}
}

