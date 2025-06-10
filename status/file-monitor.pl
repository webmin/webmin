# file-monitor.pl
# Check the status of some file

sub get_file_status
{
local @files;
if ($_[0]->{'file'} =~ /\*|\?/) {
	@files = glob($_[0]->{'file'});
	}
else {
	@files = ( $_[0]->{'file'} );
	}
my $allup = 1;
my @badsizes;
my @badowners;
my @badgroups;
my @badperms;
my @allsizes;
foreach my $f (@files) {
	local @st = stat($f);

	# Check file size
	local $size;
	local $up;
	if ($_[0]->{'test'} >= 2) {
		$size = -d $f ? &disk_usage_kb($f)*1024 : $st[7];
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
	if (!$up) {
		$allup = 0;
		push(@badsizes, $f);
		}

	if ($_[0]->{'owner'}) {
		# Check for owner
		my $u = getpwuid($st[4]);
		if ($st[4] ne $_[0]->{'owner'} &&
		    $u ne $_[0]->{'owner'}) {
			$allup = 0;
			push(@badowners, $f);
			}
		}

	if ($_[0]->{'group'}) {
		# Check for group
		my $g = getgrgid($st[5]);
		if ($st[5] ne $_[0]->{'group'} &&
		    $g ne $_[0]->{'group'}) {
			$allup = 0;
			push(@badgroups, $f);
			}
		}

	if ($_[0]->{'perms'}) {
		# Check for permissions
		if (($st[2]&0777) != oct($_[0]->{'perms'})) {
			$allup = 0;
			push(@badperms, $f);
			}
		}

	push(@allsizes, $size) if (defined($size));
	}

# Construct error message
my @descs;
if (@badsizes) {
	my $desc = join(" ", @badsizes);
	if ($_[0]->{'test'} == 2) {
		$desc = &text('file_esmall', $desc);
		}
	elsif ($_[0]->{'test'} == 3) {
		$desc = &text('file_elarge', $desc);
		}
	push(@descs, $desc);
	}
if (@badowners) {
	push(@descs, &text('file_eowner', join(" ", @badowners)));
	}
if (@badgroups) {
	push(@descs, &text('file_egroup', join(" ", @badgroups)));
	}
if (@badperms) {
	push(@descs, &text('file_eperm', join(" ", @badperms)));
	}

my $rv = { 'up' => $allup,
	   'desc' => join(", ", @descs) };
if (@allsizes == 1) {
	$rv->{'value'} = $allsizes[0];
	$rv->{'nice_value'} = &nice_size($allsizes[0]);
	}
return $rv;
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

print &ui_table_row($text{'file_owner'},
	&ui_opt_textbox("owner", $_[0]->{'owner'}, 20,
			$text{'file_nocheck'}), 3);

print &ui_table_row($text{'file_group'},
	&ui_opt_textbox("group", $_[0]->{'group'}, 20,
			$text{'file_nocheck'}), 3);

print &ui_table_row($text{'file_perms'},
	&ui_opt_textbox("perms", $_[0]->{'perms'}, 4,
			$text{'file_nocheck'}), 3);
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
$_[0]->{'owner'} = $in{'owner_def'} ? undef : $in{'owner'};
$_[0]->{'group'} = $in{'group_def'} ? undef : $in{'group'};
$_[0]->{'perms'} = $in{'perms_def'} ? undef : $in{'perms'};
}

