do 'mount-lib.pl';

sub list_system_info
{
    my $can = &foreign_available($module_name) && $access{'sysinfo'};

    if ((length($config{'sysinfo'}) && !$config{'sysinfo'}) || !$can) {
        return ();
    }

    my @disk_space = defined(&mount::local_disk_space) ? mount::local_disk_space() : ();
    my $desc = ucwords($text{'edit_usage'});
    my $html;
    my $open = 0;
    if (@disk_space) {
        &load_theme_library();
        $html = ui_columns_start(
                                 [ucwords($text{'index_dir'}), ucwords($text{'index_type'}),
                                  ucwords($text{'edit_free'}), ucwords($text{'sysinfo_total'}),
                                  ucwords($text{'sysinfo_dev'}),
                                 ]);
        foreach my $disks (@disk_space) {
            if (ref($disks)) {
                foreach my $disk (@$disks) {
                    my $total = $disk->{'total'};
                    next if (!$total);
                    my $dev_id       = $disk->{'device'};
                    my $dir          = $disk->{'dir'};
                    my $type         = $disk->{'type'};
                    my $total_nice   = nice_size($total);
                    my $free         = $disk->{'free'};
                    my $free_nice    = nice_size($disk->{'free'});
                    my $free_percent = 100 - int(($total - $free) / $total * 100);
                    my $free_percent_html;

                    if ($free_percent > 49) {
                        $free_percent_html = ui_text_color("$free_percent%", 'success');
                    } elsif ($free_percent > 9) {
                        $free_percent_html = ui_text_color("$free_percent%", 'warn');
                    } else {
                        $open = 1;
                        $free_percent_html = ui_text_color("$free_percent%", 'danger');
                    }
                    $html .= ui_columns_row([$dir, $type, $free_percent_html . " ($free_nice)", $total_nice, $dev_id,]);
                }
            }
        }
        $html .= ui_columns_end();
    }
    return (
            { 'type' => 'html',
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
