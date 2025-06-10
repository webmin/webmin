
require 'fdisk-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the fdisk module
sub acl_security_form
{
my ($o) = @_;
my @dlist = &list_disks_partitions();

print &ui_table_row($text{'acl_disks'},
	&ui_radio("disks_def", $o->{'disks'} eq '*' ? 1 : 0,
		  [ [ 1, $text{'acl_dall'} ],
		    [ 0, $text{'acl_dsel'} ] ])."<br>\n".
	&ui_select("disks",
		   [ split(/\s+/, $o->{'disks'}) ],
		   [ map { [ $_->{'device'}, &text('select_device', uc($_->{'type'}), uc(substr($_->{'device'}, -1))).($_->{'model'} ? " ($_->{'model'})" : "") ] } @dlist ],
		   4, 1), 3);

print &ui_table_row($text{'acl_view'},
	&ui_yesno_radio("view", $o->{'view'}));
}

# acl_security_save(&options)
# Parse the form for security options for the fdisk module
sub acl_security_save
{
my ($o) = @_;
if ($in{'disks_def'}) {
	$o->{'disks'} = "*";
	}
else {
	$o->{'disks'} = join(" ", split(/\0/, $in{'disks'}));
	}
$o->{'view'} = $in{'view'};
}

