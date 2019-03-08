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
    if (@disk_space) {
        $html = ui_columns_start(
                                 [ucwords($text{'index_dir'}), ucwords($text{'index_type'}),
                                  ucwords($text{'edit_free'}), ucwords($text{'sysinfo_total'}),
                                  ucwords($text{'sysinfo_dev'}),
                                 ]);
        foreach my $disks (@disk_space) {
            if (ref($disks)) {
                foreach my $disk (@$disks) {
                    my $dev_id       = $disk->{'device'};
                    my $dir          = $disk->{'dir'};
                    my $type         = $disk->{'type'};
                    my $total        = $disk->{'total'};
                    my $total_nice   = nice_size($disk->{'total'});
                    my $free         = $disk->{'free'};
                    my $free_nice    = nice_size($disk->{'free'});
                    my $free_percent = int(($total - $free) / $total * 100);
                    $html .= ui_columns_row([$dir, $type, $free_percent . "% ($free_nice)", $total_nice, $dev_id,]);
                }
            }
        }
        $html .= ui_columns_end();
    }
    return (
            { 'type'     => 'html',
              'desc'     => $desc,
              'open'     => 1,
              'id'       => $module_name . '_disks_info',
              'html'     => $html
            });
}

sub ucwords
{
    $_[0] =~ s/(\w+)/\u$1/g;
    return $_[0];
}
