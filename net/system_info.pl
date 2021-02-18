do 'net-lib.pl';

sub list_system_info
{
    my $can = &foreign_available($module_name) && $access{'sysinfo'};

    if (!$can) {
        return ();
    }

    my @net  = defined(&net::active_interfaces) ? net::active_interfaces() : ();
    my $desc = ucwords($text{'ifcs_title'});
    my ($html, $html_start, $html_rows, $html_end);
    my ($is_speed, $is_ipv6);
    my $ipv6t = $text{'ifcs_ip6'};
    my $open  = 0;

    if (@net) {
        @net = sort iface_sort @net;
        &load_theme_library();
        foreach $a (@net) {
            next if ($a->{'fullname'} eq 'lo');

            my $name = &html_escape($a->{'fullname'});
            if ($a->{'virtual'} ne "") {
                $name = "&nbsp;&nbsp;" . $name;
            }
            my $type  = &net::iface_type($a->{'name'});
            my $speed = $a->{'speed'};
            $is_speed = 1 if ($speed);
            my $ip = &html_escape($a->{'address'}) || $text{'ifcs_noaddress'};

            my $ipv6 = '';
            if (&net::supports_address6()) {
                $ipv6    = join("<br>\n", map {&html_escape($_)} @{ $a->{'address6'} });
                $is_ipv6 = 1 if ($ipv6);
                $ipv6t   = $text{'ifcs_mode6'} if ($ipv6 =~ /<br>/);
            }

            my $mask  = &html_escape($a->{'netmask'})   || $text{'ifcs_nonetmask'};
            my $broad = &html_escape($a->{'broadcast'}) || "";
            my $status =
              $a->{'up'} ? &ui_text_color($text{'ifcs_act'}, 'success') : &ui_text_color($text{'ifcs_down'}, 'danger');
            $open = 1 if (!$a->{'up'});

            $html_rows .= &ui_columns_row([$name, $type, $speed, $ip, $ipv6, $mask, $broad, $status]);
        }

        $html_start = &ui_columns_start(
            [ucwords($text{'ifcs_name'}),
             ucwords($text{'ifcs_type'}),
             $is_speed && ucwords($text{'ifcs_speed'}),
             ucwords($text{'ifcs_ip'}),
             $is_ipv6 && ucwords($ipv6t),
             ucwords($text{'ifcs_mask'}),
             ucwords($text{'ifcs_broad'}),
             ucwords($text{'ifcs_act'}),
            ]);
        $html_end .= &ui_columns_end();
        $html = ($html_start . $html_rows . $html_end) if ($html_rows);
    }
    return (
            { 'type' => 'html',
              'desc' => $desc,
              'open' => $open,
              'id'   => $module_name . '_net_info',
              'html' => $html
            });
}

sub ucwords
{
    $_[0] =~ s/(\w+)/\u$1/g;
    return $_[0];
}
