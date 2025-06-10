# iface-monitor.pl
# Check if a network interface is up or down

sub get_iface_status
{
return { 'up' => -1 } if (!&foreign_check("net"));
&foreign_require("net", "net-lib.pl");
local @act = &net::active_interfaces(1);
local $a;
foreach $a (@act) {
	if ($a->{'fullname'} eq $_[0]->{'iface'} &&
	    $a->{'up'}) {
		return { 'up' => 1 };
		}
	}
return { 'up' => 0 };
}

sub show_iface_dialog
{
&foreign_require("net", "net-lib.pl");
local %done;
local @ifaces = grep { !$done{$_->{'fullname'}}++ }
		  sort { $a->{'fullname'} cmp $b->{'fullname'} }
		     (&net::boot_interfaces(), &net::active_interfaces());
print &ui_table_row($text{'iface_iface'},
	&ui_select("iface", $_[0]->{'iface'},
	   [ map { [ $_->{'fullname'},
		     $_->{'fullname'}.
		     " (".&net::iface_type($_->{'fullname'}).")" ] } @ifaces]));
}

sub parse_iface_dialog
{
&depends_check($_[0], "net");
$_[0]->{'iface'} = $in{'iface'};
}

