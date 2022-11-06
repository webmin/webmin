
require 'spam-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the spam module
sub acl_security_form
{
my ($o) = @_;

# Allowed features
my @opts = ('white', 'score', 'report', 'user', 'header', 'priv', 'setup',
	    'procmail', 'amavisd', 'db', 'awl', 'manual');
print &ui_table_row($text{'acl_avail'},
	&ui_select("avail",
		   [ split(/,/, $o->{'avail'}) ],
		   [ map { [ $_, $text{$_."_title"} ] } @opts ],
		   6, 1), 3);

# Config file to edit
print &ui_table_row($text{'acl_file'},
	&ui_opt_textbox("file", $o->{'file'}, 60, $text{'acl_filedef'}), 3);

# Allowed auto-whitelist users
print &ui_table_row($text{'acl_awl'},
	&ui_radio("awl_mode", $o->{'awl_groups'} ? 2 :
				    $o->{'awl_users'} ? 1 : 0,
	[ [ 0, $text{'acl_awl0'}."<br>\n" ],
	  [ 1, &text('acl_awl1',
		&ui_textbox("awl_users", $o->{'awl_users'}, 40).
		&user_chooser_button("awl_users", 1))."<br>\n" ],
	  [ 2, &text('acl_awl2',
		&ui_textbox("awl_groups", $o->{'awl_groups'}, 40).
		&group_chooser_button("awl_users", 1))."<br>\n" ],
	]));
}

# acl_security_save(&options)
# Parse the form for security options for the cron module
sub acl_security_save
{
my ($o) = @_;
$o->{'avail'} = join(",", split(/\0/, $in{'avail'}));
$o->{'file'} = $in{'file_def'} ? undef : $in{'file'};
delete($o->{'awl_users'});
delete($o->{'awl_groups'});
if ($in{'awl_mode'} == 1) {
	$o->{'awl_users'} = $in{'awl_users'};
	}
elsif ($in{'awl_mode'} == 2) {
	$o->{'awl_groups'} = $in{'awl_groups'};
	}
}

