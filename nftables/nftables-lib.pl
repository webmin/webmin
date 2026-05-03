# nftables-lib.pl
# Functions for reading and writing nftables rules

BEGIN { push(@INC, ".."); }; ## no critic
use WebminCore;
use strict;
use warnings;
our (%config, %access, $module_config_directory, $module_var_directory);
our ($last_config_change_flag, $last_restart_time_flag);
init_config();
%access = get_module_acl();
$last_config_change_flag = $module_var_directory."/config-flag";
$last_restart_time_flag = $module_var_directory."/restart-flag";

# check_acl(action)
# Returns true if the current Webmin user can perform an action
sub check_acl
{
my ($action) = @_;
return $access{$action} ? 1 : 0;
}

# assert_acl(action)
# Fails if the current Webmin user cannot perform an action
sub assert_acl
{
my ($action) = @_;
check_acl($action) || error(text('acl_ecannot'));
}

# table_acl_name(&table)
# Returns the ACL token for a table
sub table_acl_name
{
my ($table) = @_;
return ($table->{'family'} || '').":".($table->{'name'} || '');
}

# check_table_acl(&table)
# Returns true if the current Webmin user can manage a table
sub check_table_acl
{
my ($table) = @_;
return 0 if (!$table);
my $tables = defined($access{'tables'}) ? $access{'tables'} : '*';
return 1 if ($tables eq '*');
my $name = table_acl_name($table);
my @tokens = grep { $_ ne '' } split(/\s+/, $tables);
if (@tokens && $tokens[0] eq '!') {
	my %deny = map { $_ => 1 } @tokens[1..$#tokens];
	return !$deny{$name};
	}
my %allow = map { $_ => 1 } @tokens;
return $allow{$name} ? 1 : 0;
}

# assert_table_acl(&table)
# Fails if the current Webmin user cannot manage a table
sub assert_table_acl
{
my ($table) = @_;
check_table_acl($table) ||
	error(text('acl_etable', html_escape(nft_table_spec($table))));
}

# check_unrestricted_table_acl()
# Returns true if the current Webmin user can manage every saved table
sub check_unrestricted_table_acl
{
my $tables = defined($access{'tables'}) ? $access{'tables'} : '*';
return $tables eq '*';
}

# check_manual_acl()
# Returns true if the current user can edit the full saved rules file
sub check_manual_acl
{
return check_acl('manual') && check_unrestricted_table_acl();
}

# assert_manual_acl()
# Fails if the current user cannot edit the full saved rules file
sub assert_manual_acl
{
check_acl('manual') || error(text('acl_ecannot'));
check_unrestricted_table_acl() || error(text('manual_etables'));
}

# restart_button()
# Returns HTML for the header apply button
sub restart_button
{
return "" if (!check_acl('apply'));
my @tables = get_nftables_save();
return "" if (!@tables);
my $args = "redir=".urlize(this_url());
my $needs = needs_config_restart();
my $apply = text('index_apply_changes');
my $label = $needs ? "<b>$apply</b>" : $apply;
my $url = "restart.cgi?$args";
$url .= "&newconfig=1" if ($needs);
return ui_link($url, $label);
}

# this_url()
# Returns the URL in the nftables module for the current script
sub this_url
{
my $url = $ENV{'SCRIPT_NAME'} || "";
my $query = $ENV{'QUERY_STRING'} || "";
$url .= "?$query" if ($query ne "");
return $url;
}

# update_last_config_change()
# Updates the flag file indicating when the saved config was changed
sub update_last_config_change
{
open_lock_tempfile(my $fh, ">$last_config_change_flag", 0, 1);
close_tempfile($fh);
}

# restart_last_restart_time()
# Updates the flag file indicating when the saved config was applied
sub restart_last_restart_time
{
open_lock_tempfile(my $fh, ">$last_restart_time_flag", 0, 1);
close_tempfile($fh);
}

# needs_config_restart()
# Returns 1 if saved config changes still need to be applied
sub needs_config_restart
{
my @cst = stat($last_config_change_flag);
my @rst = stat($last_restart_time_flag);
return 0 if (!@cst);
return 1 if (!@rst);
return $cst[9] > $rst[9] ? 1 : 0;
}

# get_nft_command()
# Returns the configured nft command path, or finds it in PATH
sub get_nft_command
{
my $cmd = $config{'nft_cmd'} || "nft";
return has_command($cmd);
}

# nft_version_text()
# Returns a friendly nftables version string for page subtitles
sub nft_version_text
{
my $cmd = get_nft_command();
return undef if (!$cmd);
my $out = backquote_command(quotemeta($cmd)." --version 2>&1");
return undef if ($? || !$out);
$out =~ s/\r?\n.*$//s;
$out =~ s/^\s+|\s+$//g;
if ($out =~ /^nftables\s+v?(\S+)(?:\s+(.*))?$/i) {
	my $details = $2 || "";
	$details =~ s/^\s+|\s+$//g;
	return text('index_version',
		    $1.($details ne "" ? " ".$details : ""));
	}
return $out;
}

# check_nftables()
# Returns an error message if nftables is not installed, undef if all is OK
sub check_nftables
{
return undef if (get_nft_command());
return text('index_ecommand', "<tt>nft</tt>");
}

# nftables_rules_file()
# Returns the Webmin-managed nftables rules file
sub nftables_rules_file
{
return "$module_config_directory/rules.conf";
}

# get_nftables_config_files()
# Returns files that can be manually edited by this module
sub get_nftables_config_files
{
my @files;
push(@files, nftables_rules_file());

foreach my $sysfile ("/etc/nftables.conf", "/etc/sysconfig/nftables.conf") {
	push(@files, $sysfile) if (-f $sysfile);
	}

if (-d "/etc/nftables") {
	opendir(my $dir, "/etc/nftables");
	if ($dir) {
		foreach my $name (sort readdir($dir)) {
			next if ($name =~ /^\./);
			next if ($name !~ /\.(?:nft|conf)$/);
			my $path = "/etc/nftables/$name";
			push(@files, $path) if (-f $path);
			}
		closedir($dir);
		}
	}

my %seen;
return grep { !$seen{$_}++ } @files;
}

# validate_nftables_text(text)
# Returns an error if nft rejects the supplied ruleset text
sub validate_nftables_text
{
my ($text) = @_;
my $cmd = get_nft_command();
return text('index_ecommand', "<tt>nft</tt>") if (!$cmd);
my $tmp = tempname();
open_tempfile(my $fh, ">$tmp");
print_tempfile($fh, $text);
close_tempfile($fh);
my $out = backquote_logged("$cmd -c -f $tmp 2>&1");
unlink_file($tmp);
return $? ? "<pre>$out</pre>" : undef;
}

# get_nftables_save([file])
# Returns a list of tables and their chains/rules
sub get_nftables_save
{
my ($file) = @_;
if (!$file) {
    $file = nftables_rules_file();
}
return ( ) if (!$file);
return ( ) if ($file !~ /\|\s*$/ && !-r $file);

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
my $is_pipe = $file =~ /\|\s*$/;
if ($is_pipe) {
    (my $pipe_cmd = $file) =~ s/\|\s*$//;
    open($fh, '-|', $pipe_cmd);
} else {
    lock_file($file);
    open($fh, '<', $file);
}
$content = do { local $/; <$fh> };
close($fh);
unlock_file($file) if (!$is_pipe);

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
    elsif ($line =~ /^\s*flags\s+(.+?)\s*;?$/ && $table && !$chain) {
        $table->{'flags'} = $1;
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

# get_active_nftables_save()
# Returns an array ref of tables from the active ruleset, and an optional error
sub get_active_nftables_save
{
my $cmd = get_nft_command();
return (undef, text('index_ecommand', "<tt>nft</tt>")) if (!$cmd);

my $out = backquote_command("$cmd list ruleset 2>&1");
return (undef, "<pre>$out</pre>") if ($?);

my $tmp = tempname();
open_tempfile(my $fh, ">$tmp");
print_tempfile($fh, $out);
close_tempfile($fh);
my @tables = get_nftables_save($tmp);
unlink_file($tmp);
return (\@tables, undef);
}

# tokenize_nft_rule(rule-text)
# Splits an nftables rule line into parser tokens
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

# unquote_nft_string(string)
# Removes nftables-style quotes and escapes from a string token
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

# escape_nft_string(string)
# Escapes a string for use inside nftables double quotes
sub escape_nft_string
{
my ($s) = @_;
return "" if (!defined($s));
$s =~ s/\\/\\\\/g;
$s =~ s/"/\\"/g;
return $s;
}

# guess_addr_family(address, [fallback])
# Returns ip or ip6 based on an address-like value
sub guess_addr_family
{
my ($addr, $fallback) = @_;
return $fallback if ($fallback);
return "ip6" if (defined($addr) && $addr =~ /:/);
return "ip";
}

# validate_chain_base(type, hook, priority, policy)
# Returns true if a chain has a complete or empty base-chain definition
sub validate_chain_base
{
my ($type, $hook, $priority, $policy) = @_;
if (defined($type) || defined($hook) || defined($priority) || defined($policy)) {
    return 0 if (!defined($type) || !defined($hook) ||
                 !defined($priority) || !defined($policy));
}
return 1;
}

# reindex_table_rules(&table)
# Updates rule index fields to match their array positions
sub reindex_table_rules
{
my ($table) = @_;
return if (!$table || ref($table) ne 'HASH' ||
	   !$table->{'rules'} || ref($table->{'rules'}) ne 'ARRAY');
for (my $i = 0; $i < @{$table->{'rules'}}; $i++) {
	my $r = $table->{'rules'}->[$i];
	$r->{'index'} = $i if ($r && ref($r) eq 'HASH');
	}
return;
}

# find_input_chain(&table)
# Returns the best input chain for adding inbound quick rules
sub find_input_chain
{
my ($table) = @_;
return if (!$table || ref($table) ne 'HASH' ||
	   !$table->{'chains'} || ref($table->{'chains'}) ne 'HASH');
# Quick IP rules must live in the selected table's input chain. A separate
# table cannot reliably allow traffic, because another input chain can still
# drop the packet later.
foreach my $c (sort keys %{$table->{'chains'}}) {
	my $chain = $table->{'chains'}->{$c} || { };
	return $c if ($c eq 'input' && ($chain->{'hook'} || '') eq 'input');
	}
foreach my $c (sort keys %{$table->{'chains'}}) {
	my $chain = $table->{'chains'}->{$c} || { };
	return $c if (($chain->{'hook'} || '') eq 'input');
	}
return $table->{'chains'}->{'input'} ? 'input' : undef;
}

# parse_ip_cidr(string)
# Returns address, nftables family and optional error for an IPv4/IPv6 CIDR
sub parse_ip_cidr
{
my ($ip) = @_;
$ip = "" if (!defined($ip));
$ip =~ s/^\s+//;
$ip =~ s/\s+$//;
return (undef, undef, text('quick_eip')) if ($ip eq '' || $ip =~ /\s/);
return (undef, undef, text('quick_eip')) if ($ip =~ tr/\/// > 1);

my $mask;
my $addr = $ip;
if ($addr =~ s/\/(\d+)$//) {
	$mask = $1;
	}
elsif ($addr =~ /\//) {
	return (undef, undef, text('quick_eip'));
	}

if (check_ipaddress($addr)) {
	return (undef, undef, text('quick_eip')) if (defined($mask) && $mask > 32);
	return ($addr.(defined($mask) ? "/".$mask : ""), 'ip', undef);
	}
if (check_ip6address($addr)) {
	return (undef, undef, text('quick_eip')) if (defined($mask) && $mask > 128);
	return ($addr.(defined($mask) ? "/".$mask : ""), 'ip6', undef);
	}
return (undef, undef, text('quick_eip'));
}

# quick_rule_type(&rule)
# Returns allow or block if this rule was created by the quick IP controls
sub quick_rule_type
{
my ($rule) = @_;
return if (!$rule || ref($rule) ne 'HASH');
return 'allow' if (($rule->{'comment'} || '') eq 'Webmin quick allow');
return 'block' if (($rule->{'comment'} || '') eq 'Webmin quick block');
return;
}

# add_quick_ip_rule(&table, ip-cidr, action)
# Adds an allow or block source-address rule to the table's input chain
sub add_quick_ip_rule
{
my ($table, $ip, $action) = @_;
return text('quick_etable') if (!$table || ref($table) ne 'HASH');
$action = $action eq 'allow' ? 'allow' : $action eq 'block' ? 'block' : '';
return text('quick_eaction') if (!$action);

my ($source, $family, $err) = parse_ip_cidr($ip);
return $err if ($err);

if (($table->{'family'} || '') eq 'ip' && $family ne 'ip' ||
    ($table->{'family'} || '') eq 'ip6' && $family ne 'ip6' ||
    ($table->{'family'} || '') !~ /^(inet|ip|ip6)$/) {
	return text('quick_efamily', nft_table_spec($table));
	}

my $chain = find_input_chain($table);
return text('quick_echain', nft_table_spec($table)) if (!$chain);

$table->{'rules'} ||= [ ];
foreach my $r (@{$table->{'rules'} || [ ]}) {
	next if (!$r || ref($r) ne 'HASH');
	next if (($r->{'chain'} || '') ne $chain);
	next if (($r->{'saddr'} || '') ne $source);
	next if (($r->{'action'} || '') ne ($action eq 'allow' ? 'accept' : 'drop'));
	next if (!quick_rule_type($r));
	return text('quick_edup', $source);
	}

my $rule = {
	'chain' => $chain,
	'saddr' => $source,
	'saddr_family' => $family,
	'action' => $action eq 'allow' ? 'accept' : 'drop',
	'comment' => $action eq 'allow' ? 'Webmin quick allow' :
				      'Webmin quick block',
	};
$rule->{'text'} = format_rule_text($rule);

my $insert = scalar(@{$table->{'rules'} || [ ]});
# Keep quick allow rules first, then quick block rules, then normal input
# rules. This makes the quick controls predictable regardless of later rules.
for (my $i = 0; $i < @{$table->{'rules'} || [ ]}; $i++) {
	my $r = $table->{'rules'}->[$i];
	next if (!$r || ref($r) ne 'HASH');
	next if (($r->{'chain'} || '') ne $chain);
	my $qt = quick_rule_type($r);
	if ($action eq 'allow') {
		next if ($qt && $qt eq 'allow');
		$insert = $i;
		last;
		}
	else {
		next if ($qt && ($qt eq 'allow' || $qt eq 'block'));
		$insert = $i;
		last;
		}
	}
splice(@{$table->{'rules'}}, $insert, 0, $rule);
reindex_table_rules($table);
return;
}

# move_rule_in_chain(&table, chain, index, direction)
# Moves one rule within its chain and returns true if changed
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

reindex_table_rules($table);

return 1;
}

# format_addr_expr(direction, &rule)
# Formats a source or destination address expression
sub format_addr_expr
{
my ($dir, $rule) = @_;
my $val = $rule->{$dir};
return if (!defined($val) || $val eq '');
my $fam = guess_addr_family($val, $rule->{$dir."_family"});
return $fam." ".$dir." ".$val;
}

# format_l4proto_expr(&rule)
# Formats a layer-4 protocol expression
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

# format_port_expr(direction, &rule)
# Formats a source or destination port expression
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

# format_tcp_flags_expr(&rule)
# Formats a TCP flags expression
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

# format_limit_expr(&rule)
# Formats a rate limit expression
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

# format_log_expr(&rule)
# Formats a log expression
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

# parse_rule_text(rule-text)
# Parses one nftables rule line into structured fields where possible
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

# format_rule_text(&rule)
# Formats a structured rule hash into nftables rule text
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

# parse_set_elements_string(string)
# Parses a comma-separated nftables set elements string
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

# parse_set_elements_input(string)
# Parses set elements from textarea input
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

# set_elements_text(&set)
# Returns set elements formatted for textarea editing
sub set_elements_text
{
my ($set) = @_;
return "" if (!$set || ref($set) ne 'HASH');
return "" if (!$set->{'elements'} || ref($set->{'elements'}) ne 'ARRAY');
return join("\n", @{$set->{'elements'}});
}

# set_elements_summary(&set)
# Returns a short set elements summary for table listings
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

# normalize_port_set_elements(elements)
# Removes overlaps from port set elements so interval sets are valid
sub normalize_port_set_elements
{
my (@elements) = @_;
my (@ranges, @other);
foreach my $e (@elements) {
	if ($e =~ /^(\d+)-(\d+)$/) {
		my ($start, $end) = ($1, $2);
		($start, $end) = ($end, $start) if ($start > $end);
		push(@ranges, [ $start, $end ]);
		}
	elsif ($e =~ /^(\d+)$/) {
		push(@ranges, [ $1, $1 ]);
		}
	else {
		push(@other, $e);
		}
	}
@ranges = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @ranges;
my @merged;
foreach my $r (@ranges) {
	if (@merged && $r->[0] <= $merged[-1]->[1]) {
		$merged[-1]->[1] = $r->[1] if ($r->[1] > $merged[-1]->[1]);
		}
	else {
		push(@merged, [ @$r ]);
		}
	}
return (
	map { $_->[0] == $_->[1] ? $_->[0] : $_->[0]."-".$_->[1] } @merged,
	sort port_sort @other
	);
}

# port_sort(a, b)
# Sorts nftables service ports and ranges by starting port number
sub port_sort
{
my ($aa) = $a =~ /^(\d+)/;
my ($bb) = $b =~ /^(\d+)/;
return ($aa || 0) <=> ($bb || 0) || $a cmp $b;
}

# set_type_kind(type)
# Returns addr, port or undef for a set type
sub set_type_kind
{
my ($type) = @_;
return if (!defined($type));
return 'addr' if ($type =~ /addr$/);
return 'port' if ($type =~ /(service|port)$/);
return;
}

# set_type_family(type)
# Returns ip or ip6 for address set types
sub set_type_family
{
my ($type) = @_;
return if (!defined($type));
return 'ip6' if ($type eq 'ipv6_addr');
return 'ip' if ($type eq 'ipv4_addr');
return;
}

# set_name_from_value(value)
# Returns the set name from an @set reference value
sub set_name_from_value
{
my ($val) = @_;
return if (!defined($val));
return $1 if ($val =~ /^\@(\S+)$/);
return;
}

# rule_uses_set(&rule, set-name)
# Returns true if a rule references a set
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

# count_set_references(&table, set-name)
# Returns the number of rules in a table that reference a set
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

# validate_set_references(&table)
# Returns an error if any structured rule uses a set in an incompatible field
sub validate_set_references
{
my ($table) = @_;
return if (!$table || ref($table) ne 'HASH');
return if (!$table->{'sets'} || ref($table->{'sets'}) ne 'HASH');
return if (!$table->{'rules'} || ref($table->{'rules'}) ne 'ARRAY');
foreach my $r (@{$table->{'rules'}}) {
	next if (!$r || ref($r) ne 'HASH');
	foreach my $check (
		[ 'saddr', 'addr', text('edit_saddr') ],
		[ 'daddr', 'addr', text('edit_daddr') ],
		[ 'sport', 'port', text('edit_sport') ],
		[ 'dport', 'port', text('edit_dport') ],
		) {
		my ($field, $want, $label) = @$check;
		my $setname = set_name_from_value($r->{$field});
		next if (!$setname);
		my $set = $table->{'sets'}->{$setname};
		next if (!$set);
		my $kind = set_type_kind($set->{'type'});
		if (!$kind || $kind ne $want) {
			my $type = $set->{'type'} || text('set_type_select');
			return text('apply_esettype', $setname,
				    nft_table_spec($table), $type,
				    $r->{'chain'} || "-", $label);
			}
		}
	}
return;
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

# write_configuration(@tables)
# Writes the configuration to the save file
sub write_configuration
{
my (@tables) = @_;
my $out = dump_nftables_save(@tables);
my $file = nftables_rules_file();

open_lock_tempfile(my $fh, ">$file");
print_tempfile($fh, $out);
close_tempfile($fh);
sync_managed_metadata(@tables);
update_last_config_change();
return;
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
# Writes the configuration to the save file
sub save_configuration
{
my (@tables) = @_;
write_configuration(@tables);
return;
}

# create_table_configuration(&table, @tables)
# Writes the full configuration after creating a table
sub create_table_configuration
{
my ($table, @tables) = @_;
write_configuration(@tables);
return;
}

# save_table_configuration(&table, @tables)
# Writes the full configuration after changing a table
sub save_table_configuration
{
my ($table, @tables) = @_;
write_configuration(@tables);
return;
}

# delete_table_configuration(&table, @tables)
# Writes the full configuration after deleting a table
sub delete_table_configuration
{
my ($table, @tables) = @_;
write_configuration(@tables);
return;
}

# apply_restore([file])
# Applies Webmin-managed tables from the save file
sub apply_restore
{
my ($file) = @_;
$file ||= nftables_rules_file();
my $cmd = get_nft_command();
return text('index_ecommand', "<tt>nft</tt>") if (!$cmd);

my @tables = get_nftables_save($file);
return text('apply_enone') if (!@tables);

my ($active, $active_err) = get_active_nftables_save();
return $active_err if ($active_err);

my %active;
foreach my $t (@$active) {
    $active{table_key($t)} = $t;
}
foreach my $t (@tables) {
    my $set_err = validate_set_references($t);
    return $set_err if ($set_err);
    my $active_table = $active{table_key($t)};
    if ($active_table && table_is_externally_managed($active_table)) {
        return text('apply_eexternal', nft_table_spec($t));
    }
}

my $tmp = tempname();
open_tempfile(my $fh, ">$tmp");
foreach my $t (@tables) {
    print_tempfile($fh, "delete table ".nft_table_spec($t)."\n")
        if ($active{table_key($t)});
}
print_tempfile($fh, dump_nftables_save(@tables));
close_tempfile($fh);

my $out = backquote_logged("$cmd -c -f $tmp 2>&1");
if (!$?) {
    $out = backquote_logged("$cmd -f $tmp 2>&1");
}
unlink_file($tmp);
if ($?) {
    return "<pre>$out</pre>";
}
restart_last_restart_time();
return;
}

# delete_active_table(&table)
# Deletes one table from the active ruleset if it exists
sub delete_active_table
{
my ($table) = @_;
my $cmd = get_nft_command();
return text('index_ecommand', "<tt>nft</tt>") if (!$cmd);

my ($active, $active_err) = get_active_nftables_save();
return $active_err if ($active_err);

my $active_table;
foreach my $t (@$active) {
	if (table_key($t) eq table_key($table)) {
		$active_table = $t;
		last;
		}
	}
return if (!$active_table);
if (table_is_externally_managed($active_table)) {
	return text('apply_eexternal', nft_table_spec($table));
	}

my $tmp = tempname();
open_tempfile(my $fh, ">$tmp");
print_tempfile($fh, "delete table ".nft_table_spec($table)."\n");
close_tempfile($fh);

my $out = backquote_logged("$cmd -c -f $tmp 2>&1");
if (!$?) {
	$out = backquote_logged("$cmd -f $tmp 2>&1");
	}
unlink_file($tmp);
if ($?) {
	return "<pre>$out</pre>";
	}
return;
}

# nft_table_spec(&table)
# Returns a table spec for nft commands
sub nft_table_spec
{
my ($table) = @_;
return $table->{'family'} ? "$table->{'family'} $table->{'name'}" :
                            $table->{'name'};
}

# table_key(&table)
# Returns a stable key for a table
sub table_key
{
my ($table) = @_;
return ($table->{'family'} || '')."\0".($table->{'name'} || '');
}

# table_is_externally_managed(&table)
# Returns true if an active table is marked as owned by another program
sub table_is_externally_managed
{
my ($table) = @_;
return 0 if (!$table || !$table->{'flags'});
my %flags = map { $_ => 1 } grep { $_ ne '' } split(/[,\s]+/, $table->{'flags'});
return $flags{'owner'} || $flags{'persist'};
}

# table_is_webmin_managed(&table, [&saved_tables])
# Returns true if an active table is present in Webmin's saved config
sub table_is_webmin_managed
{
my ($table, $saved_tables) = @_;
if (!$saved_tables) {
	my @tables = get_nftables_save();
	$saved_tables = \@tables;
	}
foreach my $t (@$saved_tables) {
	return 1 if (table_key($t) eq table_key($table));
	}
return 0;
}

# active_table_status(&table, [&saved_tables])
# Returns webmin, external or unclaimed for an active table
sub active_table_status
{
my ($table, $saved_tables) = @_;
return "external" if (table_is_externally_managed($table));
return "webmin" if (table_is_webmin_managed($table, $saved_tables));
return "unclaimed";
}

# managed_metadata_file()
# Returns the path to Webmin's nftables metadata file
sub managed_metadata_file
{
return "$module_config_directory/managed.json";
}

# managed_table_key(&table)
# Returns the key used for managed table metadata
sub managed_table_key
{
my ($table) = @_;
return nft_table_spec($table);
}

# read_managed_metadata()
# Returns metadata about tables managed by this module
sub read_managed_metadata
{
my $file = managed_metadata_file();
return parse_managed_metadata(undef) if (!-r $file);
lock_file($file);
my $json = read_file_contents($file);
unlock_file($file);
return parse_managed_metadata($json);
}

# parse_managed_metadata(json)
# Parses managed table metadata, returning an empty structure on failure
sub parse_managed_metadata
{
my ($json) = @_;
my $meta = eval { convert_from_json($json) };
if (!$meta || ref($meta) ne 'HASH') {
	$meta = { };
	}
if (!$meta->{'tables'} || ref($meta->{'tables'}) ne 'HASH') {
	$meta->{'tables'} = { };
	}
return $meta;
}

# sync_managed_metadata(@tables)
# Keeps managed metadata aligned with the saved Webmin config
sub sync_managed_metadata
{
my (@tables) = @_;
my $file = managed_metadata_file();
lock_file($file);
my $meta = -r $file ? parse_managed_metadata(read_file_contents($file)) :
		      { 'tables' => { } };
my %old = %{$meta->{'tables'}};
my %new;
foreach my $t (@tables) {
	my $key = managed_table_key($t);
	my %entry = $old{$key} && ref($old{$key}) eq 'HASH' ?
		%{$old{$key}} : ( );
	$entry{'family'} = $t->{'family'};
	$entry{'name'} = $t->{'name'};
	$entry{'source'} ||= 'webmin';
	$entry{'managed_at'} ||= time();
	$new{$key} = \%entry;
	}
$meta->{'tables'} = \%new;
write_file_contents($file, convert_to_json($meta, 1));
unlock_file($file);
return;
}

# register_managed_table(&table, %info)
# Adds or updates metadata for a Webmin-managed table
sub register_managed_table
{
my ($table, %info) = @_;
my $file = managed_metadata_file();
lock_file($file);
my $meta = -r $file ? parse_managed_metadata(read_file_contents($file)) :
		      { 'tables' => { } };
my $key = managed_table_key($table);
my %entry = $meta->{'tables'}->{$key} &&
	    ref($meta->{'tables'}->{$key}) eq 'HASH' ?
		%{$meta->{'tables'}->{$key}} : ( );
foreach my $k (keys %info) {
	$entry{$k} = $info{$k};
	}
$entry{'family'} = $table->{'family'};
$entry{'name'} = $table->{'name'};
$entry{'source'} ||= 'webmin';
$entry{'managed_at'} ||= time();
$meta->{'tables'}->{$key} = \%entry;
write_file_contents($file, convert_to_json($meta, 1));
unlock_file($file);
return;
}

# unregister_managed_table(&table)
# Removes metadata for a table no longer managed by this module
sub unregister_managed_table
{
my ($table) = @_;
my $file = managed_metadata_file();
lock_file($file);
my $meta = -r $file ? parse_managed_metadata(read_file_contents($file)) :
		      { 'tables' => { } };
delete($meta->{'tables'}->{managed_table_key($table)});
write_file_contents($file, convert_to_json($meta, 1));
unlock_file($file);
return;
}

# describe_rule(&rule)
# Returns a human-readable rule summary for listings
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

# get_usermin_port()
# Returns the configured Usermin port, or 20000 if unknown
sub get_usermin_port
{
my %miniserv;
if (foreign_installed("usermin")) {
	foreign_require("usermin", "usermin-lib.pl");
	usermin::get_usermin_miniserv_config(\%miniserv);
	if ($miniserv{'port'} =~ /^\d+$/) {
		return $miniserv{'port'};
		}
	}
return 20000;
}

1;
