#!/usr/bin/perl
# save_rule.cgi
# Save a new or existing rule

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'save_err'});
my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];

foreach my $sfield (qw(saddr_set daddr_set sport_set dport_set)) {
    if ($in{$sfield}) {
        $table->{'sets'}->{$in{$sfield}} ||
            error(text('save_set_missing', $in{$sfield}));
    }
}
foreach my $check (
    [ 'saddr_set', 'addr', $text{'edit_saddr'} ],
    [ 'daddr_set', 'addr', $text{'edit_daddr'} ],
    [ 'sport_set', 'port', $text{'edit_sport'} ],
    [ 'dport_set', 'port', $text{'edit_dport'} ],
    ) {
    my ($sfield, $want, $label) = @$check;
    next if (!$in{$sfield});
    my $set = $table->{'sets'}->{$in{$sfield}};
    my $kind = set_type_kind($set->{'type'});
    if (!$kind || $kind ne $want) {
        my $type = $set->{'type'} || $text{'set_type_select'};
        error(text('save_set_type', $in{$sfield}, $type, $label));
    }
}

sub join_multi_value
{
    my ($v) = @_;
    return if (!defined($v) || $v eq '');
    my @vals = split(/\0/, $v);
    @vals = grep { defined($_) && $_ ne '' } @vals;
    return if (!@vals);
    return join(",", @vals);
}

if ($in{'delete'}) {
    # Delete the rule
    my $rule = $table->{'rules'}->[$in{'idx'}];
    splice(@{$table->{'rules'}}, $in{'idx'}, 1);
    webmin_log("delete", "rule", $rule ? $rule->{'text'} : undef);
} else {
    my $rule = {};
    if ($in{'new'}) {
        $rule->{'chain'} = $in{'chain'};
        $rule->{'index'} = scalar(@{$table->{'rules'}});
    } else {
        $rule = $table->{'rules'}->[$in{'idx'}];
    }

    if ($in{'edit_direct'}) {
        my $raw = $in{'raw_rule'};
        $raw =~ s/\r//g if (defined($raw));
        $raw =~ s/^\s+// if (defined($raw));
        $raw =~ s/\s+$// if (defined($raw));
        error($text{'save_raw_empty'}) if (!defined($raw) || $raw eq '');
        error($text{'save_raw_multiline'}) if ($raw =~ /[\r\n]/);
        $rule->{'text'} = $raw;
    }
    else {
        $rule->{'comment'} = $in{'comment'};
        my $action = $in{'action'} || 'accept';
        $rule->{'action'} = undef;
        $rule->{'jump'} = undef;
        $rule->{'goto'} = undef;
        if ($action eq 'jump') {
            $rule->{'jump'} = $in{'jump'};
        }
        elsif ($action eq 'goto') {
            $rule->{'goto'} = $in{'goto'};
        }
        else {
            $rule->{'action'} = $action;
        }

        my $saddr = $in{'saddr'};
        my $daddr = $in{'daddr'};
        $saddr = '@'.$in{'saddr_set'} if ($in{'saddr_set'});
        $daddr = '@'.$in{'daddr_set'} if ($in{'daddr_set'});
        $rule->{'saddr'} = (defined($saddr) && $saddr ne '') ? $saddr : undef;
        $rule->{'daddr'} = (defined($daddr) && $daddr ne '') ? $daddr : undef;
        $rule->{'saddr_family'} = $rule->{'saddr'} ? guess_addr_family($rule->{'saddr'}) : undef;
        $rule->{'daddr_family'} = $rule->{'daddr'} ? guess_addr_family($rule->{'daddr'}) : undef;
        if ($rule->{'saddr'} && $rule->{'saddr'} =~ /^\@(\S+)/) {
            my $fam = set_type_family($table->{'sets'}->{$1}->{'type'});
            $rule->{'saddr_family'} = $fam if ($fam);
        }
        if ($rule->{'daddr'} && $rule->{'daddr'} =~ /^\@(\S+)/) {
            my $fam = set_type_family($table->{'sets'}->{$1}->{'type'});
            $rule->{'daddr_family'} = $fam if ($fam);
        }

        my $proto = $in{'proto'};
        $proto = undef if (defined($proto) && $proto eq '');
        my $sport = $in{'sport'};
        my $dport = $in{'dport'};
        $sport = '@'.$in{'sport_set'} if ($in{'sport_set'});
        $dport = '@'.$in{'dport_set'} if ($in{'dport_set'});
        $rule->{'sport'} = (defined($sport) && $sport ne '') ? $sport : undef;
        $rule->{'dport'} = (defined($dport) && $dport ne '') ? $dport : undef;
        if (!$proto && ($rule->{'sport'} || $rule->{'dport'})) {
            $proto = 'tcp';
        }
        $rule->{'l4proto'} = undef;
        $rule->{'l4proto_family'} = undef;
        $rule->{'proto'} = undef;
        $rule->{'sport_proto'} = undef;
        if ($proto && ($proto eq 'tcp' || $proto eq 'udp')) {
            $rule->{'proto'} = $proto if ($rule->{'sport'} || $rule->{'dport'});
            $rule->{'sport_proto'} = $proto if ($rule->{'sport'});
        }
        elsif ($proto && $proto !~ /^(tcp|udp)$/) {
            $rule->{'sport'} = undef;
            $rule->{'dport'} = undef;
        }
        if ($proto) {
            if (($proto eq 'tcp' || $proto eq 'udp') && ($rule->{'sport'} || $rule->{'dport'})) {
                # L4 proto implied by port match
            }
            else {
                $rule->{'l4proto'} = $proto;
                $rule->{'l4proto_family'} = 'meta';
            }
        }

        my $icmp_type = $in{'icmp_type'};
        $rule->{'icmp_type'} = undef;
        $rule->{'icmpv6_type'} = undef;
        if ($proto && $proto eq 'icmp') {
            $rule->{'icmp_type'} = $icmp_type if (defined($icmp_type) && $icmp_type ne '');
        }
        elsif ($proto && $proto eq 'icmpv6') {
            $rule->{'icmpv6_type'} = $icmp_type if (defined($icmp_type) && $icmp_type ne '');
        }
        elsif (!$proto && defined($icmp_type) && $icmp_type ne '') {
            $rule->{'icmp_type'} = $icmp_type;
            $rule->{'l4proto'} = 'icmp';
            $rule->{'l4proto_family'} = 'meta';
        }

        my $ct_state = join_multi_value($in{'ct_state'});
        my $tcp_flags = join_multi_value($in{'tcp_flags'});
        $rule->{'ct_state'} = defined($ct_state) ? $ct_state : undef;
        $rule->{'tcp_flags'} = defined($tcp_flags) ? $tcp_flags : undef;
        $rule->{'tcp_flags_mask'} = (defined($in{'tcp_flags_mask'}) && $in{'tcp_flags_mask'} ne '') ? $in{'tcp_flags_mask'} : undef;
        $rule->{'limit_rate'} = (defined($in{'limit_rate'}) && $in{'limit_rate'} ne '') ? $in{'limit_rate'} : undef;
        $rule->{'limit_burst'} = (defined($in{'limit_burst'}) && $in{'limit_burst'} ne '') ? $in{'limit_burst'} : undef;

        my $log_enabled = $in{'log'} || $in{'log_prefix'} || $in{'log_level'};
        $rule->{'log'} = $log_enabled ? 1 : undef;
        $rule->{'log_prefix'} = $log_enabled && defined($in{'log_prefix'}) && $in{'log_prefix'} ne '' ? $in{'log_prefix'} : undef;
        $rule->{'log_level'} = $log_enabled && defined($in{'log_level'}) && $in{'log_level'} ne '' ? $in{'log_level'} : undef;
        $rule->{'counter'} = $in{'counter'} ? 1 : undef;

        my $iif = $in{'iif'};
        my $oif = $in{'oif'};
        $iif = $in{'iif_other'} if (defined($iif) && $iif eq 'other');
        $oif = $in{'oif_other'} if (defined($oif) && $oif eq 'other');
        $rule->{'iif'} = (defined($iif) && $iif ne '') ? $iif : undef;
        $rule->{'oif'} = (defined($oif) && $oif ne '') ? $oif : undef;

        $rule->{'text'} = format_rule_text($rule);
    }

    if ($in{'new'}) {
        push(@{$table->{'rules'}}, $rule);
    }

    if ($in{'edit_direct'}) {
        my $cmd = get_nft_command();
        if ($cmd) {
            my $tmp = tempname();
            open_tempfile(my $fh, ">$tmp");
            print_tempfile($fh, dump_nftables_save(@tables));
            close_tempfile($fh);
            my $out = backquote_logged("$cmd -c -f $tmp 2>&1");
            unlink_file($tmp);
            error(text('save_invalid_rule', "<pre>$out</pre>")) if ($?);
        }
    }

    webmin_log("save", $in{'new'} ? "create" : "modify", $rule->{'text'});
}
my $err = save_table_configuration($table, @tables);
error(text('save_failed', $err)) if ($err);
redirect("index.cgi?table=$in{'table'}");
