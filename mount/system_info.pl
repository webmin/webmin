do 'mount-lib.pl';

sub list_system_info
{
	# Can we get list of disk with space?
	my $can = &foreign_available($module_name) && $access{'sysinfo'};
	if ((length($config{'sysinfo'}) && !$config{'sysinfo'}) || !$can) {
		return ();
		}
	my (undef, undef, $disks, undef) = &local_disk_space();
	if (!@$disks) {
		return ();
		}

	my $desc = ucwords($text{'edit_usage'});
	my $html;
	my $open = 0;
        &load_theme_library();
        $html = &ui_columns_start([
		ucwords($text{'index_dir'}), ucwords($text{'index_type'}),
		ucwords($text{'edit_free'}), ucwords($text{'index_used'}),
		ucwords($text{'sysinfo_total'}), ucwords($text{'sysinfo_dev'}),
		]);
	foreach my $disk (@$disks) {
		my $total = $disk->{'total'};
                my $itotal = $disk->{'itotal'};
                next if (!$total);
                my $dev_id       = $disk->{'device'};
                my $dir          = $disk->{'dir'};
                my $type         = $disk->{'type'};
                my $total_nice   = &nice_size($total);
                my $free         = $disk->{'free'};
                my $ifree        = $disk->{'ifree'};
                my $used_nice    = &nice_size($disk->{'used'} // $total - $free);
                my $free_nice    = &nice_size($free);
                my $free_percent = 100 - ($disk->{'used_percent'} // int(($total - $free) / $total * 100));
                my $free_percent_html;
                    
                # Inodes percent
                my $ifree_percent_html;
                my $itotal_full;
                my $iused;
                my $ifree_percent;
                $ifree_percent = 100 - int(($itotal - $ifree) / $itotal * 100)
			if ($itotal);

                # Calc percents
                if ($free_percent > 49) {
			$free_percent_html = &ui_text_color("$free_percent%", 'success');
                        $ifree_percent_html = &ui_text_color("$ifree_percent%", 'success')
                            if ($itotal);
			}
                elsif ($free_percent > 9) {
                        $free_percent_html = &ui_text_color("$free_percent%", 'warn');
                        $ifree_percent_html = &ui_text_color("$ifree_percent%", 'warn')
                            if ($itotal);
			}
                else {
                        $open = 1;
                        $free_percent_html = &ui_text_color("$free_percent%", 'danger');
                        $ifree_percent_html = &ui_text_color("$ifree_percent%", 'danger')
                            if ($itotal);
			}

                # Inodes total
                if ($itotal) {
                        $ifree_percent_html = "<span><br>".$ifree_percent_html." ($ifree inodes)</span>";
                        $itotal_full = "<span><br>$itotal inodes</span>";
                        $iused = "<span><br>@{[$disk->{'iused'} // $disk->{'itotal'} - $disk->{'ifree'}]} inodes</span>";
                        }
                $html .= &ui_columns_row([
			$dir, $type,
			$free_percent_html." ($free_nice)$ifree_percent_html",
			$used_nice.$iused,
			$total_nice.$itotal_full,
			$dev_id]);
		}
	$html .= &ui_columns_end();
	return ({ 'type' => 'html',
	       'desc' => $desc,
	       'open' => $open,
	       'id'   => $module_name . '_disks_info',
	       'html' => $html
	    });
}

sub ucwords
{
    $_[0] =~ s/(\w+)/\u$1/g;
    return $_[0];
}
