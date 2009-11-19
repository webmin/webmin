# file-monitor.pl
# Check the status of some file

sub get_file_status
{
local @st = stat($_[0]->{'file'});
local $size;
if ($_[0]->{'test'} >= 2) {
	$size = -d $_[0]->{'file'} ? &disk_usage_kb($_[0]->{'file'})*1024
				   : $st[7];
	}
if ($_[0]->{'test'} == 0) {
	$up = @st ? 1 : 0;
	}
elsif ($_[0]->{'test'} == 1) {
	$up = @st ? 0 : 1;
	}
elsif ($_[0]->{'test'} == 2) {
	$up = $size > $_[0]->{'greater'} ? 1 : 0;
	}
elsif ($_[0]->{'test'} == 3) {
	$up = $size < $_[0]->{'lesser'} ? 1 : 0;
	}
return { 'up' => $up };
}

sub show_file_dialog
{
print &ui_table_row($text{'file_file'},
	&ui_textbox("file", $_[0]->{'file'}, 50), 3);

print &ui_table_row($text{'file_test'},
	&ui_radio("test", int($_[0]->{'test'}),
		[ [ 0, $text{'file_test_0'}."<br>" ],
		  [ 1, $text{'file_test_1'}."<br>" ],
		  [ 2, $text{'file_test_2'}.
		       &ui_textbox("greater", $_[0]->{'greater'}, 10)." ".
		       $text{'file_bytes'}."<br>" ],
		  [ 3, $text{'file_test_3'}.
		       &ui_textbox("lesser", $_[0]->{'lesser'}, 10)." ".
		       $text{'file_bytes'}."<br>" ] ]), 3);
}

sub parse_file_dialog
{
$in{'file'} || &error($text{'file_efile'});
$_[0]->{'file'} = $in{'file'};
$_[0]->{'test'} = $in{'test'};
$in{'greater'} =~ /^\d*$/ && $in{'lesser'} =~ /^\d*$/ ||
	&error($text{'file_esize'});
$_[0]->{'greater'} = $in{'greater'};
$_[0]->{'lesser'} = $in{'lesser'};
}

