# init-monitor.pl
# Check if a bootup service is running

sub get_init_status
{
return { 'up' => -1 } if (!&foreign_installed("init"));
&foreign_require("init");
local $st = &init::status_action($_[0]->{'action'});
return { 'up' => $st };
}

sub show_init_dialog
{
&foreign_require("init");
local @actions = &init::list_action_names();
print &ui_table_row($text{'init_action'},
	&ui_select("action", $_[0]->{'action'}, \@actions));
}

sub parse_init_dialog
{
&depends_check($_[0], "init");
$in{'action'} || &error($text{'init_eaction'});
$_[0]->{'action'} = $in{'action'};
}

