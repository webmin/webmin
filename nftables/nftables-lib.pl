# nftables-lib.pl
# Functions for reading and writing nftables rules

BEGIN { push(@INC, ".."); }; ## no critic
use WebminCore;
use strict;
use warnings;
our (%config, $module_config_directory);
init_config();

# get_nft_command()
# Returns the configured nft command path, or finds it in PATH
sub get_nft_command
{
my $cmd = $config{'nft_cmd'} || "nft";
return has_command($cmd);
}

# check_nftables()
# Returns an error message if nftables is not installed, undef if all is OK
sub check_nftables
{
return undef if (get_nft_command());
return text('index_ecommand', "<tt>nft</tt>");
}

# get_nftables_save([file])
# Returns a list of tables and their chains/rules
sub get_nftables_save
{
my ($file) = @_;
my $cmd = get_nft_command();
if (!$file) {
    if ($config{'direct'}) {
        return ( ) if (!$cmd);
        $file = "$cmd list ruleset |";
    } else {
        $file = $config{'save_file'} || "$module_config_directory/nftables.conf";
    }
}
return ( ) if (!$file);

my @rv;
my $table;
my $chain;
my $set;
my $set_depth = 0;
my $set_elem_open = 0;
my $set_elem_buf = '';
my $lnum = 0;
my $content;
my $fh;
if ($file =~ /\|\s*$/) {
    (my $pipe_cmd = $file) =~ s/\|\s*$//;
    open($fh, '-|', $pipe_cmd);
} else {
    open($fh, '<', $file);
}
$content = do { local $/; <$fh> };
close($fh);

my @lines = split /\r?\n/, $content;
for(my $i=0; $i<@lines; $i++) {
    my $line = $lines[$i];
    $lnum++;
    $line =~ s/#.*$//; # Ignore comments for now

    if ($set) {
        my $sline = $line;
        $sline =~ s/^\s+//;
        $sline =~ s/\s+$//;
        if ($set_elem_open) {
            if ($sline =~ /(.*)\}/) {
                $set_elem_buf .= " ".$1;
                $set_elem_open = 0;
                $set_elem_buf =~ s/;\s*$//;
                $set->{'elements'} = parse_set_elements_string($set_elem_buf);
                $set_elem_buf = '';
            }
            else {
                $set_elem_buf .= " ".$sline if ($sline ne '');
            }
        }
        else {
            if ($sline =~ /^type\s+(\S+)\s*;?$/) {
                $set->{'type'} = $1;
                $set->{'type'} =~ s/;\s*$//;
            }
            elsif ($sline =~ /^flags\s+(.+?)\s*;?$/) {
                $set->{'flags'} = $1;
            }
            elsif ($sline =~ /^elements\s*=\s*\{(.*)$/) {
                my $rest = $1;
                if ($rest =~ /(.*)\}/) {
                    my $content = $1;
                    $content =~ s/;\s*$//;
                    $set->{'elements'} = parse_set_elements_string($content);
                }
                else {
                    $set_elem_open = 1;
                    $set_elem_buf = $rest;
                }
            }
            elsif ($sline ne '' && $sline ne '}') {
                push(@{$set->{'raw_lines'}}, $sline);
            }
        }

        my $opens = () = $line =~ /\{/g;
        my $closes = () = $line =~ /\}/g;
        $set_depth += $opens - $closes;
        if ($set_depth <= 0) {
            $set = undef;
            $set_depth = 0;
            $set_elem_open = 0;
            $set_elem_buf = '';
        }
        next;
    }
    
    if ($line =~ /^table\s+(\S+)\s+(\S+)\s+\{/) {
        # Start of a table
        $table = { 'name' => $2,
                   'family' => $1,
                   'line' => $lnum,
                   'rules' => [ ],
                   'chains' => { },
                   'sets' => { } };
        push(@rv, $table);
        $chain = undef;
    }
    elsif ($line =~ /^\s*set\s+(\S+)\s+\{/) {
        # Start of a set
        if ($table) {
            my $setname = $1;
            $set = {
                'name' => $setname,
                'line' => $lnum,
                'elements' => [ ],
                'raw_lines' => [ ],
            };
            $table->{'sets'}->{$setname} = $set;
            $set_depth = () = $line =~ /\{/g;
            $set_depth -= () = $line =~ /\}/g;
            $set_elem_open = 0;
            $set_elem_buf = '';
        }
    }
    elsif ($line =~ /^\s*chain\s+(\S+)\s+\{/) {
        # Start of a chain
        if ($table) {
            $chain = $1;
            $table->{'chains'}->{$chain} = { };
            
            # Look at next line for chain definition
            if ($lines[$i+1] =~ /^\s*type\s+(\S+)\s+hook\s+(\S+)\s+priority\s+(.+?);\s+policy\s+(\S+);/) {
                $table->{'chains'}->{$chain}->{'type'} = $1;
                $table->{'chains'}->{$chain}->{'hook'} = $2;
                $table->{'chains'}->{$chain}->{'priority'} = $3;
                $table->{'chains'}->{$chain}->{'policy'} = $4;
                $i++; # Skip next line
            }
        }
    }
    elsif ($line =~ /^\s*(.*?)$/ && $table && $chain && $1 ne "}") {
        # A rule
        my $rule_str = $1;
        if ($rule_str =~ /\S/) {
           my $rule = {
               'text' => $rule_str,
               'chain' => $chain,
               'index' => scalar(@{$table->{'rules'}}),
               'line' => $lnum
           };
           my $parsed = parse_rule_text($rule_str);
           if ($parsed) {
               foreach my $k (keys %$parsed) {
                   $rule->{$k} = $parsed->{$k};
               }
           }
           push(@{$table->{'rules'}}, $rule);
        }
    }
}

return @rv;
}

sub tokenize_nft_rule
{
my ($line) = @_;
my @tokens;
my $i = 0;
my $len = length($line);
while ($i < $len) {
    my $ch = substr($line, $i, 1);
    if ($ch =~ /\s/) {
        $i++;
        next;
    }
    if ($ch eq '"' || $ch eq "'") {
        my $q = $ch;
        my $j = $i + 1;
        my $esc = 0;
        while ($j < $len) {
            my $c = substr($line, $j, 1);
            if ($esc) {
                $esc = 0;
            }
            elsif ($c eq "\\") {
                $esc = 1;
            }
            elsif ($c eq $q) {
                $j++;
                last;
            }
            $j++;
        }
        push(@tokens, substr($line, $i, $j-$i));
        $i = $j;
        next;
    }
    if ($ch eq '{') {
        my $j = $i + 1;
        my $depth = 1;
        while ($j < $len && $depth > 0) {
            my $c = substr($line, $j, 1);
            if ($c eq '{') {
                $depth++;
            }
            elsif ($c eq '}') {
                $depth--;
            }
            $j++;
        }
        push(@tokens, substr($line, $i, $j-$i));
        $i = $j;
        next;
    }
    my $j = $i;
    while ($j < $len && substr($line, $j, 1) !~ /\s/) {
        $j++;
    }
    push(@tokens, substr($line, $i, $j-$i));
    $i = $j;
}
return @tokens;
}

sub unquote_nft_string
{
my ($s) = @_;
return $s if (!defined($s));
if ($s =~ /^"(.*)"$/s) {
    $s = $1;
    $s =~ s/\\(["\\])/$1/g;
}
elsif ($s =~ /^'(.*)'$/s) {
    $s = $1;
    $s =~ s/\\(['\\])/$1/g;
}
return $s;
}

sub escape_nft_string
{
my ($s) = @_;
return "" if (!defined($s));
$s =~ s/\\/\\\\/g;
$s =~ s/"/\\"/g;
return $s;
}

sub guess_addr_family
{
my ($addr, $fallback) = @_;
return $fallback if ($fallback);
return "ip6" if (defined($addr) && $addr =~ /:/);
return "ip";
}

sub validate_chain_base
{
my ($type, $hook, $priority, $policy) = @_;
if (defined($type) || defined($hook) || defined($priority) || defined($policy)) {
    return 0 if (!defined($type) || !defined($hook) ||
                 !defined($priority) || !defined($policy));
}
return 1;
}

sub move_rule_in_chain
{
my ($table, $chain, $idx, $dir) = @_;
return if (!defined($table) || ref($table) ne 'HASH');
return if (!defined($idx) || $idx !~ /^\d+$/);
return if (!defined($chain) || $chain eq '');
return if (!$table->{'rules'} || ref($table->{'rules'}) ne 'ARRAY');
return if ($idx > $#{$table->{'rules'}});
my $rule = $table->{'rules'}->[$idx];
return if (!$rule || $rule->{'chain'} ne $chain);

my @chain_idxs;
for (my $i = 0; $i < @{$table->{'rules'}}; $i++) {
    my $r = $table->{'rules'}->[$i];
    next if (!$r || ref($r) ne 'HASH');
    push(@chain_idxs, $i) if ($r->{'chain'} && $r->{'chain'} eq $chain);
}
my $pos;
for (my $i = 0; $i <= $#chain_idxs; $i++) {
    if ($chain_idxs[$i] == $idx) {
        $pos = $i;
        last;
    }
}
return if (!defined($pos));

my $swap;
if ($dir eq 'up') {
    return 0 if ($pos == 0);
    $swap = $chain_idxs[$pos-1];
}
elsif ($dir eq 'down') {
    return 0 if ($pos == $#chain_idxs);
    $swap = $chain_idxs[$pos+1];
}
else {
    return;
}

($table->{'rules'}->[$idx], $table->{'rules'}->[$swap]) =
    ($table->{'rules'}->[$swap], $table->{'rules'}->[$idx]);

for (my $i = 0; $i < @{$table->{'rules'}}; $i++) {
    my $r = $table->{'rules'}->[$i];
    $r->{'index'} = $i if ($r && ref($r) eq 'HASH');
}

return 1;
}

sub format_addr_expr
{
my ($dir, $rule) = @_;
my $val = $rule->{$dir};
return if (!defined($val) || $val eq '');
my $fam = guess_addr_family($val, $rule->{$dir."_family"});
return $fam." ".$dir." ".$val;
}

sub format_l4proto_expr
{
my ($rule) = @_;
my $proto = $rule->{'l4proto'};
return if (!defined($proto) || $proto eq '');
my $fam = $rule->{'l4proto_family'} || 'meta';
if ($fam eq 'ip' || $fam eq 'ip6') {
    return $fam." protocol ".$proto;
}
return "meta l4proto ".$proto;
}

sub format_port_expr
{
my ($dir, $rule) = @_;
my $val = $rule->{$dir};
return if (!defined($val) || $val eq '');
my $proto;
if ($dir eq 'sport') {
    $proto = $rule->{'sport_proto'} || $rule->{'proto'} || $rule->{'l4proto'};
}
else {
    $proto = $rule->{'proto'} || $rule->{'l4proto'};
}
return if (!defined($proto) || $proto eq '');
return $proto." ".$dir." ".$val;
}

sub format_tcp_flags_expr
{
my ($rule) = @_;
return if (!defined($rule->{'tcp_flags'}) || $rule->{'tcp_flags'} eq '');
my $val = $rule->{'tcp_flags'};
if (defined($rule->{'tcp_flags_mask'}) && $rule->{'tcp_flags_mask'} ne '') {
    return "tcp flags & ".$rule->{'tcp_flags_mask'}." == ".$val;
}
return "tcp flags ".$val;
}

sub format_limit_expr
{
my ($rule) = @_;
return if (!defined($rule->{'limit_rate'}) || $rule->{'limit_rate'} eq '');
my $out = "limit rate ".$rule->{'limit_rate'};
if (defined($rule->{'limit_burst'}) && $rule->{'limit_burst'} ne '') {
    my $burst = $rule->{'limit_burst'};
    $out .= " burst ".$burst;
    $out .= " packets" if ($burst =~ /^\d+$/);
}
return $out;
}

sub format_log_expr
{
my ($rule) = @_;
return if (!$rule->{'log'} && !$rule->{'log_prefix'} && !$rule->{'log_level'});
my @p = ("log");
if (defined($rule->{'log_prefix'}) && $rule->{'log_prefix'} ne '') {
    my $pfx = escape_nft_string($rule->{'log_prefix'});
    push(@p, "prefix", "\"".$pfx."\"");
}
if (defined($rule->{'log_level'}) && $rule->{'log_level'} ne '') {
    push(@p, "level", $rule->{'log_level'});
}
return join(" ", @p);
}

sub parse_rule_text
{
my ($line) = @_;
return { } if (!defined($line));
my %rule;
my @tokens = tokenize_nft_rule($line);
my @exprs;
my $i = 0;
while ($i < @tokens) {
    my $tok = $tokens[$i];

    if ($tok eq 'comment' && $i+1 < @tokens) {
        my $raw = $tokens[$i]." ".$tokens[$i+1];
        $rule{'comment'} = unquote_nft_string($tokens[$i+1]);
        push(@exprs, { 'type' => 'comment', 'text' => $raw });
        $i += 2;
        next;
    }
    if (($tok eq 'iif' || $tok eq 'iifname') && $i+1 < @tokens) {
        my $raw = $tok." ".$tokens[$i+1];
        $rule{'iif'} = unquote_nft_string($tokens[$i+1]);
        $rule{'iif_type'} = $tok;
        push(@exprs, { 'type' => 'iif', 'text' => $raw });
        $i += 2;
        next;
    }
    if (($tok eq 'oif' || $tok eq 'oifname') && $i+1 < @tokens) {
        my $raw = $tok." ".$tokens[$i+1];
        $rule{'oif'} = unquote_nft_string($tokens[$i+1]);
        $rule{'oif_type'} = $tok;
        push(@exprs, { 'type' => 'oif', 'text' => $raw });
        $i += 2;
        next;
    }
    if (($tok eq 'ip' || $tok eq 'ip6') && $i+2 < @tokens &&
        ($tokens[$i+1] eq 'saddr' || $tokens[$i+1] eq 'daddr')) {
        my $which = $tokens[$i+1];
        my $val = $tokens[$i+2];
        my $raw = $tok." ".$which." ".$val;
        $rule{$which} = $val;
        $rule{$which."_family"} = $tok;
        push(@exprs, { 'type' => $which, 'text' => $raw });
        $i += 3;
        next;
    }
    if (($tok eq 'ip' || $tok eq 'ip6') && $i+2 < @tokens &&
        $tokens[$i+1] eq 'protocol') {
        my $val = $tokens[$i+2];
        my $raw = $tok." protocol ".$val;
        $rule{'l4proto'} = $val;
        $rule{'l4proto_family'} = $tok;
        push(@exprs, { 'type' => 'l4proto', 'text' => $raw });
        $i += 3;
        next;
    }
    if ($tok eq 'meta' && $i+2 < @tokens &&
        $tokens[$i+1] eq 'l4proto') {
        my $val = $tokens[$i+2];
        my $raw = "meta l4proto ".$val;
        $rule{'l4proto'} = $val;
        $rule{'l4proto_family'} = 'meta';
        push(@exprs, { 'type' => 'l4proto', 'text' => $raw });
        $i += 3;
        next;
    }
    if ($tok eq 'tcp' && $i+1 < @tokens && $tokens[$i+1] eq 'flags') {
        my $j = $i + 2;
        my $mask;
        my $val;
        if ($j < @tokens && $tokens[$j] eq '&' && $j+1 < @tokens) {
            $mask = $tokens[$j+1];
            $j += 2;
        }
        if ($j < @tokens && $tokens[$j] eq '==' && $j+1 < @tokens) {
            $val = $tokens[$j+1];
            $j += 2;
        }
        elsif ($j < @tokens) {
            $val = $tokens[$j];
            $j++;
        }
        my $raw = join(" ", @tokens[$i..($j-1)]);
        $rule{'tcp_flags'} = $val if (defined($val));
        $rule{'tcp_flags_mask'} = $mask if (defined($mask));
        push(@exprs, { 'type' => 'tcp_flags', 'text' => $raw });
        $i = $j;
        next;
    }
    if (($tok eq 'tcp' || $tok eq 'udp') && $i+2 < @tokens &&
        ($tokens[$i+1] eq 'dport' || $tokens[$i+1] eq 'sport')) {
        my $dir = $tokens[$i+1];
        my $val = $tokens[$i+2];
        my $raw = $tok." ".$dir." ".$val;
        if ($dir eq 'dport') {
            $rule{'proto'} = $tok;
            $rule{'dport'} = $val;
        }
        else {
            $rule{'sport'} = $val;
            $rule{'sport_proto'} = $tok;
        }
        push(@exprs, { 'type' => $dir, 'text' => $raw, 'proto' => $tok });
        $i += 3;
        next;
    }
    if (($tok eq 'icmp' || $tok eq 'icmpv6') && $i+2 < @tokens &&
        $tokens[$i+1] eq 'type') {
        my $val = $tokens[$i+2];
        my $raw = $tok." type ".$val;
        if ($tok eq 'icmp') {
            $rule{'icmp_type'} = $val;
        }
        else {
            $rule{'icmpv6_type'} = $val;
        }
        push(@exprs, { 'type' => $tok, 'text' => $raw });
        $i += 3;
        next;
    }
    if ($tok eq 'ct' && $i+2 < @tokens && $tokens[$i+1] eq 'state') {
        my $val = $tokens[$i+2];
        my $raw = "ct state ".$val;
        $rule{'ct_state'} = $val;
        push(@exprs, { 'type' => 'ct_state', 'text' => $raw });
        $i += 3;
        next;
    }
    if ($tok eq 'limit') {
        my $j = $i + 1;
        my @lt = ($tok);
        if ($j < @tokens && $tokens[$j] eq 'rate' && $j+1 < @tokens) {
            push(@lt, $tokens[$j], $tokens[$j+1]);
            $rule{'limit_rate'} = $tokens[$j+1];
            $j += 2;
            if ($j < @tokens && $tokens[$j] eq 'burst' && $j+1 < @tokens) {
                push(@lt, $tokens[$j], $tokens[$j+1]);
                $rule{'limit_burst'} = $tokens[$j+1];
                $j += 2;
                if ($j < @tokens && $tokens[$j] eq 'packets') {
                    push(@lt, $tokens[$j]);
                    $j++;
                }
            }
        }
        my $raw = join(" ", @lt);
        push(@exprs, { 'type' => 'limit', 'text' => $raw });
        $i = $j;
        next;
    }
    if ($tok eq 'log') {
        my $j = $i + 1;
        my @lt = ($tok);
        while ($j < @tokens) {
            if ($tokens[$j] eq 'prefix' && $j+1 < @tokens) {
                $rule{'log_prefix'} = unquote_nft_string($tokens[$j+1]);
                push(@lt, $tokens[$j], $tokens[$j+1]);
                $j += 2;
                next;
            }
            if ($tokens[$j] eq 'level' && $j+1 < @tokens) {
                $rule{'log_level'} = $tokens[$j+1];
                push(@lt, $tokens[$j], $tokens[$j+1]);
                $j += 2;
                next;
            }
            last;
        }
        $rule{'log'} = 1;
        my $raw = join(" ", @lt);
        push(@exprs, { 'type' => 'log', 'text' => $raw });
        $i = $j;
        next;
    }
    if ($tok eq 'counter') {
        $rule{'counter'} = 1;
        push(@exprs, { 'type' => 'counter', 'text' => $tok });
        $i++;
        next;
    }
    if ($tok =~ /^(accept|drop|reject|return)$/) {
        $rule{'action'} = $tok;
        push(@exprs, { 'type' => 'action', 'text' => $tok });
        $i++;
        next;
    }
    if (($tok eq 'jump' || $tok eq 'goto') && $i+1 < @tokens) {
        my $raw = $tok." ".$tokens[$i+1];
        $rule{$tok} = $tokens[$i+1];
        push(@exprs, { 'type' => $tok, 'text' => $raw });
        $i += 2;
        next;
    }

    push(@exprs, { 'type' => 'raw', 'text' => $tok });
    $i++;
}
$rule{'exprs'} = \@exprs;
return \%rule;
}

sub format_rule_text
{
my ($rule) = @_;
return "" if (!$rule || ref($rule) ne 'HASH');
my @parts;
my %used;
my $exprs = $rule->{'exprs'};
if ($exprs && ref($exprs) eq 'ARRAY' && @$exprs) {
    foreach my $e (@$exprs) {
        my $type = $e->{'type'} || 'raw';
        if ($type eq 'action' || $type eq 'comment') {
            next;
        }
        if ($type eq 'iif') {
            if (!$used{'iif'} && defined($rule->{'iif'}) && $rule->{'iif'} ne '') {
                my $iftype = $rule->{'iif_type'} || 'iif';
                my $ival = escape_nft_string($rule->{'iif'});
                push(@parts, $iftype." \"".$ival."\"");
                $used{'iif'} = 1;
            }
            next;
        }
        if ($type eq 'oif') {
            if (!$used{'oif'} && defined($rule->{'oif'}) && $rule->{'oif'} ne '') {
                my $oftype = $rule->{'oif_type'} || 'oif';
                my $oval = escape_nft_string($rule->{'oif'});
                push(@parts, $oftype." \"".$oval."\"");
                $used{'oif'} = 1;
            }
            next;
        }
        if ($type eq 'saddr') {
            if (!$used{'saddr'}) {
                my $addr = format_addr_expr('saddr', $rule);
                if ($addr) {
                    push(@parts, $addr);
                    $used{'saddr'} = 1;
                }
            }
            next;
        }
        if ($type eq 'daddr') {
            if (!$used{'daddr'}) {
                my $addr = format_addr_expr('daddr', $rule);
                if ($addr) {
                    push(@parts, $addr);
                    $used{'daddr'} = 1;
                }
            }
            next;
        }
        if ($type eq 'l4proto') {
            if (!$used{'l4proto'}) {
                my $lp = format_l4proto_expr($rule);
                if ($lp) {
                    push(@parts, $lp);
                    $used{'l4proto'} = 1;
                }
            }
            next;
        }
        if ($type eq 'sport') {
            if (!$used{'sport'}) {
                my $sp = format_port_expr('sport', $rule);
                if ($sp) {
                    push(@parts, $sp);
                    $used{'sport'} = 1;
                }
            }
            next;
        }
        if ($type eq 'dport') {
            if (!$used{'dport'} && $rule->{'proto'} && $rule->{'dport'}) {
                my $dp = format_port_expr('dport', $rule);
                if ($dp) {
                    push(@parts, $dp);
                    $used{'dport'} = 1;
                }
            }
            next;
        }
        if ($type eq 'icmp') {
            if (!$used{'icmp'} && $rule->{'icmp_type'}) {
                push(@parts, "icmp type ".$rule->{'icmp_type'});
                $used{'icmp'} = 1;
            }
            next;
        }
        if ($type eq 'icmpv6') {
            if (!$used{'icmpv6'} && $rule->{'icmpv6_type'}) {
                push(@parts, "icmpv6 type ".$rule->{'icmpv6_type'});
                $used{'icmpv6'} = 1;
            }
            next;
        }
        if ($type eq 'ct_state') {
            if (!$used{'ct_state'} && $rule->{'ct_state'}) {
                push(@parts, "ct state ".$rule->{'ct_state'});
                $used{'ct_state'} = 1;
            }
            next;
        }
        if ($type eq 'tcp_flags') {
            if (!$used{'tcp_flags'}) {
                my $tf = format_tcp_flags_expr($rule);
                if ($tf) {
                    push(@parts, $tf);
                    $used{'tcp_flags'} = 1;
                }
            }
            next;
        }
        if ($type eq 'limit') {
            if (!$used{'limit'}) {
                my $lim = format_limit_expr($rule);
                if ($lim) {
                    push(@parts, $lim);
                    $used{'limit'} = 1;
                }
            }
            next;
        }
        if ($type eq 'log') {
            if (!$used{'log'}) {
                my $lg = format_log_expr($rule);
                if ($lg) {
                    push(@parts, $lg);
                    $used{'log'} = 1;
                }
            }
            next;
        }
        if ($type eq 'counter') {
            if (!$used{'counter'} && $rule->{'counter'}) {
                push(@parts, "counter");
                $used{'counter'} = 1;
            }
            next;
        }
        if ($type eq 'jump') {
            if (!$used{'jump'} && $rule->{'jump'}) {
                push(@parts, "jump ".$rule->{'jump'});
                $used{'jump'} = 1;
            }
            next;
        }
        if ($type eq 'goto') {
            if (!$used{'goto'} && $rule->{'goto'}) {
                push(@parts, "goto ".$rule->{'goto'});
                $used{'goto'} = 1;
            }
            next;
        }
        push(@parts, $e->{'text'}) if ($e->{'text'});
    }
}
if (!$used{'iif'} && defined($rule->{'iif'}) && $rule->{'iif'} ne '') {
    my $iftype = $rule->{'iif_type'} || 'iif';
    my $ival = escape_nft_string($rule->{'iif'});
    push(@parts, $iftype." \"".$ival."\"");
}
if (!$used{'oif'} && defined($rule->{'oif'}) && $rule->{'oif'} ne '') {
    my $oftype = $rule->{'oif_type'} || 'oif';
    my $oval = escape_nft_string($rule->{'oif'});
    push(@parts, $oftype." \"".$oval."\"");
}
if (!$used{'saddr'}) {
    my $addr = format_addr_expr('saddr', $rule);
    push(@parts, $addr) if ($addr);
}
if (!$used{'daddr'}) {
    my $addr = format_addr_expr('daddr', $rule);
    push(@parts, $addr) if ($addr);
}
if (!$used{'l4proto'}) {
    my $lp = format_l4proto_expr($rule);
    push(@parts, $lp) if ($lp);
}
if (!$used{'sport'}) {
    my $sp = format_port_expr('sport', $rule);
    push(@parts, $sp) if ($sp);
}
if (!$used{'dport'}) {
    my $dp = format_port_expr('dport', $rule);
    push(@parts, $dp) if ($dp);
}
if (!$used{'icmp'} && $rule->{'icmp_type'}) {
    push(@parts, "icmp type ".$rule->{'icmp_type'});
}
if (!$used{'icmpv6'} && $rule->{'icmpv6_type'}) {
    push(@parts, "icmpv6 type ".$rule->{'icmpv6_type'});
}
if (!$used{'tcp_flags'}) {
    my $tf = format_tcp_flags_expr($rule);
    push(@parts, $tf) if ($tf);
}
if (!$used{'ct_state'} && $rule->{'ct_state'}) {
    push(@parts, "ct state ".$rule->{'ct_state'});
}
if (!$used{'limit'}) {
    my $lim = format_limit_expr($rule);
    push(@parts, $lim) if ($lim);
}
if (!$used{'log'}) {
    my $lg = format_log_expr($rule);
    push(@parts, $lg) if ($lg);
}
if (!$used{'counter'} && $rule->{'counter'}) {
    push(@parts, "counter");
}
if (!$used{'jump'} && $rule->{'jump'}) {
    push(@parts, "jump ".$rule->{'jump'});
}
if (!$used{'goto'} && $rule->{'goto'}) {
    push(@parts, "goto ".$rule->{'goto'});
}
if ($rule->{'action'} && !$rule->{'jump'} && !$rule->{'goto'}) {
    push(@parts, $rule->{'action'});
}
if (defined($rule->{'comment'}) && $rule->{'comment'} ne '') {
    my $c = escape_nft_string($rule->{'comment'});
    push(@parts, "comment \"".$c."\"");
}
my $text = join(" ", grep { defined($_) && $_ ne '' } @parts);
$text =~ s/^\s+//;
$text =~ s/\s+$//;
return $text;
}

sub parse_set_elements_string
{
my ($text) = @_;
return [ ] if (!defined($text));
$text =~ s/^\s+//;
$text =~ s/\s+$//;
return [ ] if ($text eq '');
my @vals = split(/\s*,\s*/, $text);
@vals = grep { defined($_) && $_ ne '' } @vals;
return \@vals;
}

sub parse_set_elements_input
{
my ($text) = @_;
return [ ] if (!defined($text));
$text =~ s/\r//g;
$text =~ s/^\s+//;
$text =~ s/\s+$//;
return [ ] if ($text eq '');
$text =~ s/\n/,/g;
return parse_set_elements_string($text);
}

sub set_elements_text
{
my ($set) = @_;
return "" if (!$set || ref($set) ne 'HASH');
return "" if (!$set->{'elements'} || ref($set->{'elements'}) ne 'ARRAY');
return join("\n", @{$set->{'elements'}});
}

sub set_elements_summary
{
my ($set) = @_;
return "-" if (!$set || ref($set) ne 'HASH');
return "-" if (!$set->{'elements'} || ref($set->{'elements'}) ne 'ARRAY');
my @elems = @{$set->{'elements'}};
return "-" if (!@elems);
my $max = 3;
my $preview = join(", ", @elems[0 .. ($#elems < $max-1 ? $#elems : $max-1)]);
if (@elems > $max) {
    $preview .= ", ...";
}
return $preview;
}

sub set_type_kind
{
my ($type) = @_;
return if (!defined($type));
return 'addr' if ($type =~ /addr$/);
return 'port' if ($type =~ /(service|port)$/);
return;
}

sub set_type_family
{
my ($type) = @_;
return if (!defined($type));
return 'ip6' if ($type eq 'ipv6_addr');
return 'ip' if ($type eq 'ipv4_addr');
return;
}

sub set_name_from_value
{
my ($val) = @_;
return if (!defined($val));
return $1 if ($val =~ /^\@(\S+)$/);
return;
}

sub rule_uses_set
{
my ($rule, $setname) = @_;
return 0 if (!$rule || !$setname);
foreach my $k (qw(saddr daddr sport dport)) {
    return 1 if (defined($rule->{$k}) && $rule->{$k} eq '@'.$setname);
}
return 1 if ($rule->{'text'} && $rule->{'text'} =~ /\@\Q$setname\E\b/);
return 0;
}

sub count_set_references
{
my ($table, $setname) = @_;
return 0 if (!$table || ref($table) ne 'HASH' || !$setname);
return 0 if (!$table->{'rules'} || ref($table->{'rules'}) ne 'ARRAY');
my $count = 0;
foreach my $r (@{$table->{'rules'}}) {
    next if (!$r || ref($r) ne 'HASH');
    $count++ if (rule_uses_set($r, $setname));
}
return $count;
}


# dump_nftables_save(@tables)
# Returns a string representation of the firewall rules
sub dump_nftables_save
{
my (@tables) = @_;
my $rv;
foreach my $t (@tables) {
    if ($t->{'family'}) {
        $rv .= "table $t->{'family'} $t->{'name'} {\n";
    } else {
        $rv .= "table $t->{'name'} {\n";
    }

    if ($t->{'sets'} && ref($t->{'sets'}) eq 'HASH') {
        foreach my $s (sort keys %{$t->{'sets'}}) {
            my $set = $t->{'sets'}->{$s};
            next if (!$set || ref($set) ne 'HASH');
            $rv .= "\tset $s {\n";
            $rv .= "\t\ttype $set->{'type'};\n" if ($set->{'type'});
            $rv .= "\t\tflags $set->{'flags'};\n" if ($set->{'flags'});
            if ($set->{'raw_lines'} && ref($set->{'raw_lines'}) eq 'ARRAY') {
                foreach my $l (@{$set->{'raw_lines'}}) {
                    next if (!defined($l) || $l eq '');
                    $rv .= "\t\t$l\n";
                }
            }
            if ($set->{'elements'} && ref($set->{'elements'}) eq 'ARRAY' &&
                @{$set->{'elements'}}) {
                my $el = join(", ", @{$set->{'elements'}});
                $rv .= "\t\telements = { $el }\n";
            }
            $rv .= "\t}\n";
        }
    }
    
    foreach my $c (keys %{$t->{'chains'}}) {
        my $chain = $t->{'chains'}->{$c};
        $rv .= "\tchain $c {\n";
        if ($chain->{'type'}) {
            $rv .= "\t\ttype $chain->{'type'} hook $chain->{'hook'} priority $chain->{'priority'}; policy $chain->{'policy'};\n";
        }
        
        # Add rules for this chain
        my @rules = sort { $a->{'index'} <=> $b->{'index'} } 
                 grep { ref($_) eq 'HASH' && $_->{'chain'} eq $c } @{$t->{'rules'}};
        foreach my $r (@rules) {
             $rv .= "\t\t$r->{'text'}\n";
        }
        $rv .= "\t}\n";
    }
    $rv .= "}\n";
}
return $rv;
}

# save_table(&table)
# Saves a single table to the save file or applies it
sub save_table
{
my ($table) = @_;
# Re-read all tables to ensure we have the full picture if we are overwriting the file
# But here we probably just want to update the specific table in the list of tables we have.
# Since we usually operate on a list of tables, we might need to pass the full list or 
# re-read the state. 
# For simplicity, we usually load all, modify one, and save all.
}

# save_configuration(@tables)
# Writes the configuration to the save file. If direct mode is on, applies it.
sub save_configuration
{
my (@tables) = @_;
my $out = dump_nftables_save(@tables);
my $file = $config{'save_file'} || "$module_config_directory/nftables.conf";

# Write to file
open_tempfile(my $fh, ">$file");
print_tempfile($fh, $out);
close_tempfile($fh);

if ($config{'direct'}) {
    return apply_restore($file);
}
return;
}

# apply_restore([file])
# Applies the configuration from the save file
sub apply_restore
{
my ($file) = @_;
$file ||= $config{'save_file'} || "$module_config_directory/nftables.conf";
my $cmd = get_nft_command();
return text('index_ecommand', "<tt>nft</tt>") if (!$cmd);
my $out = backquote_logged("$cmd -f $file 2>&1");
if ($?) {
    return "<pre>$out</pre>";
}
return;
}

# flush_ruleset()
# Flushes all active nftables tables, chains, sets and rules
sub flush_ruleset
{
my $cmd = get_nft_command();
return text('index_ecommand', "<tt>nft</tt>") if (!$cmd);
my $out = backquote_logged("$cmd flush ruleset 2>&1");
if ($?) {
    return "<pre>$out</pre>";
}
return;
}

# describe_rule(&rule)
sub describe_rule
{
my ($r) = @_;
my @conds;
if ($r->{'iif'}) {
    push(@conds, text('index_rule_iif', html_escape($r->{'iif'})));
}
if ($r->{'oif'}) {
    push(@conds, text('index_rule_oif', html_escape($r->{'oif'})));
}
if ($r->{'saddr'}) {
    push(@conds, text('index_rule_saddr', html_escape($r->{'saddr'})));
}
if ($r->{'daddr'}) {
    push(@conds, text('index_rule_daddr', html_escape($r->{'daddr'})));
}
if ($r->{'l4proto'} || ($r->{'proto'} && !$r->{'dport'} && !$r->{'sport'})) {
    my $p = $r->{'l4proto'} || $r->{'proto'};
    push(@conds, text('index_rule_proto', html_escape($p)));
}
if ($r->{'sport'}) {
    push(@conds, text('index_rule_sport', html_escape($r->{'sport'})));
}
if ($r->{'dport'}) {
    push(@conds, text('index_rule_dport', html_escape($r->{'dport'})));
}
if ($r->{'icmp_type'}) {
    push(@conds, text('index_rule_icmp', html_escape($r->{'icmp_type'})));
}
if ($r->{'icmpv6_type'}) {
    push(@conds, text('index_rule_icmpv6', html_escape($r->{'icmpv6_type'})));
}
if ($r->{'ct_state'}) {
    push(@conds, text('index_rule_ct', html_escape($r->{'ct_state'})));
}
if ($r->{'tcp_flags'}) {
    my $tf = $r->{'tcp_flags'};
    if ($r->{'tcp_flags_mask'}) {
        $tf = $r->{'tcp_flags_mask'}."==".$r->{'tcp_flags'};
    }
    push(@conds, text('index_rule_tcpflags', html_escape($tf)));
}
if ($r->{'limit_rate'}) {
    my $lim = $r->{'limit_rate'};
    if ($r->{'limit_burst'}) {
        $lim .= " burst ".$r->{'limit_burst'};
    }
    push(@conds, text('index_rule_limit', html_escape($lim)));
}
if ($r->{'log_prefix'}) {
    push(@conds, text('index_rule_log_prefix', html_escape($r->{'log_prefix'})));
}
if ($r->{'log_level'}) {
    push(@conds, text('index_rule_log_level', html_escape($r->{'log_level'})));
}
if ($r->{'log'} && !$r->{'log_prefix'} && !$r->{'log_level'}) {
    push(@conds, text('index_rule_log'));
}
if ($r->{'counter'}) {
    push(@conds, text('index_rule_counter'));
}

my $action_label;
if ($r->{'jump'}) {
    $action_label = text('index_rule_jump', html_escape($r->{'jump'}));
}
elsif ($r->{'goto'}) {
    $action_label = text('index_rule_goto', html_escape($r->{'goto'}));
}
elsif ($r->{'action'}) {
    if ($r->{'action'} eq 'return') {
        $action_label = text('index_return_action');
    }
    else {
        $action_label = text('index_'.lc($r->{'action'}));
    }
}
if ($action_label) {
    if (@conds) {
        return text('index_rule_desc_generic', $action_label, join(", ", @conds));
    }
    return text('index_rule_desc_action', $action_label);
}
return html_escape($r->{'text'});
}

# interface_choice(name, value, blanktext)
# Returns HTML for an interface chooser menu
sub interface_choice
{
my ($name, $value, $blanktext) = @_;
if (foreign_check("net")) {
    foreign_require("net", "net-lib.pl");
    return net::interface_choice($name, $value, $blanktext, 0, 1);
}
else {
    return ui_textbox($name, $value, 20);
}
}

# get_webmin_port()
# Returns the configured Webmin port, or 10000 if unknown
sub get_webmin_port
{
my %miniserv;
if (get_miniserv_config(\%miniserv) && $miniserv{'port'} =~ /^\d+$/) {
    return $miniserv{'port'};
}
return 10000;
}

1;
