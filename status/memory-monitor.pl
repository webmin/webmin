# memory-monitor.pl
# Check the free memory

sub get_memory_status
{
return { 'up' => -1 } if (!&foreign_check("proc"));
&foreign_require("proc", "proc-lib.pl");
local @mem;
eval "\@mem = &proc::get_memory_info()";
if ($@) {
	return { 'up' => -1 };
	}
elsif ($mem[1] < $_[0]->{'min'}) {
	return { 'up' => 0 };
	}
else {
	return { 'up' => 1,
		 'desc' => &text('memory_free2', &nice_size($mem[1]*1024)) };
	}
}

sub show_memory_dialog
{
print &ui_table_row($text{'memory_min2'},
	&ui_bytesbox("min", $_[0]->{'min'}*1024));
}

sub parse_memory_dialog
{
&depends_check($_[0], "proc");
&foreign_require("proc", "proc-lib.pl");
defined(&proc::get_memory_info) || &error($text{'memory_eproc'});
$in{'min'} =~ /^[0-9\.]+$/ || &error($text{'memory_emin'});
$_[0]->{'min'} = $in{'min'}*$in{'min_units'}/1024;
}

