#!/usr/local/bin/perl
# index.cgi
# Display a list of known filesystems, and indicate which are currently mounted

require './mount-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("mount fstab vfstab", "man"));
&ReadParse();

# List filesystems from fstab and mtab
@mounted = &list_mounted();
$yes = $text{'yes'};
$no = "<font color=#ff0000>$text{'no'}</a>";
%can_edit = map { $_, 1 } &list_fstypes();
$i = 0;
foreach $m (&list_mounts()) {
	$m->[0] = "swap" if ($m->[2] eq "swap");
	$mounts{$m->[0],$m->[1]} = $i++;
	push(@all, $m);
	}
$i = 0;
foreach $m (&list_mounted()) {
	$m->[0] = "swap" if ($m->[2] eq "swap");
	$mounted{$m->[0],$m->[1]} = $i++;
	push(@all, $m) if (!defined($mounts{$m->[0],$m->[1]}));
	}

# Sort by chosen mode
if ($config{'sort_mode'} == 2) {
	@all = sort { lc($a->[0]) cmp lc($b->[0]) } @all;
	}
elsif ($config{'sort_mode'} == 1) {
	@all = sort { &fstype_name($a->[2]) cmp &fstype_name($b->[2]) } @all;
	}

# Build visible filesystems list
foreach $m (@all) {
	@minfo = @$m;
	$p = &simplify_mount_path($minfo[0], $minfo[2]);
	@mmodes = &mount_modes($minfo[2], $minfo[0], $minfo[1]);
	$canedit = $can_edit{$minfo[2]} && !$mmodes[4] &&
            	   &can_edit_fs(@minfo);
	next if (!$canedit && $access{'hide'});
	next if (!$canedit && !$in{'show'});
	push(@visible, $m);
	}

if (@visible) {
	# Show table of all visible filesystems
	if (!$access{'hide'}) {
		if ($in{'show'}) {
			$shower = &ui_link("index.cgi?show=0",
					   $text{'index_show0'});
			}
		else {
			$shower = &ui_link("index.cgi?show=1",
					   $text{'index_show1'});
			}
		}
	print &ui_links_row([ $shower ]) if ($shower);
	print &ui_columns_start([ $text{'index_dir'},
				$text{'index_type'},
				$text{'index_dev'},
				$config{'show_used'} ? ( $text{'index_used'} )
						     : ( ),
				$text{'index_use'},
				$text{'index_perm'} ], 100);
	foreach $m (@visible) {
		@minfo = @$m;
		$p = &simplify_mount_path($minfo[0], $minfo[2]);

		$midx = $mounts{$minfo[0],$minfo[1]};
		$medidx = $mounted{$minfo[0],$minfo[1]};
		@mmodes = &mount_modes($minfo[2], $minfo[0], $minfo[1]);
		$canedit = $can_edit{$minfo[2]} && !$mmodes[4] &&
			   &can_edit_fs(@minfo);
		local @cols;
		if ($canedit && !$access{'only'}) {
			if (defined($midx)) {
				push(@cols, &ui_link("edit_mount.cgi?index=$midx", $p));
				}
			else {
				push(@cols, &ui_link("edit_mount.cgi?temp=1&index=$medidx", $p));
				}
			}
		else {
			push(@cols, $p);
			}
		local $fsn = &fstype_name($minfo[2]);
		$fsn .= " ($minfo[2])" if (uc($fsn) ne uc($minfo[2]));
		push(@cols, $minfo[2] eq "*" ? $text{'index_auto'} : $fsn);
		push(@cols, &device_name($minfo[1]));
		if ($config{'show_used'}) {
			# Add disk space used column
			($total, $free) = &disk_space($minfo[2],$minfo[0]);
			if ($total > 0 && $total >= $free) {
				$pc = int(100*($total-$free) / $total);
				push(@cols,
				 $pc >= 99 ? "<font color=red>$pc %</font>" :
				 $pc >= 95 ? "<font color=orange>$pc %</font>" :
					     $pc."%");
				}
			else {
				push(@cols, "");
				}
			}
		if (&can_edit_fs(@minfo)) {
			push(@cols,
				defined($medidx) ? &ui_link("unmount.cgi?index=$medidx", $yes) : &ui_link("mount.cgi?index=$midx", $no)
                );
			}
		else {
			push(@cols, defined($medidx) ? $yes : $no);
			}
		push(@cols, defined($midx) ? $yes : $no);
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	print &ui_links_row([ $shower ]) if ($shower);
	print "<p>\n";
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
&show_button();

&ui_print_footer("/", $text{'index'});

sub simplify_mount_path
{
if ($_[1] eq "swap") {
	return "<i>$text{'index_swap'}</i>";
	}
elsif (length($_[0]) > 40) {
	return &html_escape("... ".substr($_[0], length($_[0])-40));
	}
elsif ($_[0] eq "/") {
	return "/ (<i>$text{'index_root'}</i>)";
	}
else {
	return &html_escape($_[0]);
	}
}

sub show_button
{
return if (!$access{'create'} || $access{'only'});
my %donefs;
print &ui_form_start("edit_mount.cgi");
print &ui_submit($text{'index_add'})," ",$text{'index_addtype'},"\n";
my @opts;
foreach my $fs (sort { &fstype_name($a) cmp &fstype_name($b) }
		     &list_fstypes()) {
	my $nm = &fstype_name($fs);
	if (!$donefs{$nm}++ && &can_fstype($fs)) {
		push(@opts, [ $fs, "$nm ($fs)" ]);
		}
	}
my $def = defined(&preferred_fstype) ? &preferred_fstype() : undef;
print &ui_select("type", $def, \@opts);
print &ui_form_end();
}

