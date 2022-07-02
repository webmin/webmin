#!/usr/local/bin/perl
# save_view.cgi
# Update an existing view
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'view_err'});
my $pconf = &get_config_parent();
my $conf = $pconf->{'members'};
my $view = $conf->[$in{'index'}];
$access{'views'} || &error($text{'view_ecannot'});
&can_edit_view($view) || &error($text{'view_ecannot'});
$access{'ro'} && &error($text{'view_ecannot'});

# Save the view
&lock_file(&make_chroot($view->{'file'}));
&save_addr_match("match-clients", $view, 1);
&save_choice("recursion", $view, 1);
&save_address("allow-transfer", $view, 1);
&save_address("allow-query", $view, 1);
&save_address("also-notify", $view, 1);
&save_address("allow-notify", $view, 1);

if ($in{'transfer-source'})
{
        &check_ipaddress($in{'transfer-source'}) || &error(&text('net_eaddr', $in{'transfer-source'}));
        my @tvals;
        push(@tvals, $in{'transfer-source'});
        if (@tvals)
        {
                &save_directive($view, 'transfer-source',
                [ { 'name' => 'transfer-source',
                'values' => \@tvals } ], 1);
        }
}
else
{
        &save_directive($view, 'transfer-source', [], 1);
}

&flush_file_lines();
&unlock_file(&make_chroot($view->{'file'}));
&webmin_log("view", undef, $view->{'value'}, \%in);
&redirect("");

