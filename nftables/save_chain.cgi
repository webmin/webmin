#!/usr/bin/perl
# save_chain.cgi
# Save a new or existing chain

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'chain_err'});
assert_acl('chains');

my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'chain_notable'});
assert_table_acl($table);

my $is_new = $in{'new'} ? 1 : 0;
my $is_rename = $in{'rename'} ? 1 : 0;
my $name = $in{'chain_name'};
$name =~ s/^\s+// if (defined($name));
$name =~ s/\s+$// if (defined($name));
$name =~ /^\w[\w-]*$/ || error($text{'chain_ename'});

my $old = $is_rename ? $in{'chain_old'} : $name;
$old =~ s/^\s+// if (defined($old));
$old =~ s/\s+$// if (defined($old));

if ($is_new) {
    $table->{'chains'}->{$name} && error($text{'chain_edup'});
} elsif ($is_rename) {
    $table->{'chains'}->{$old} || error($text{'chain_nochain'});
    if ($name ne $old && $table->{'chains'}->{$name}) {
        error($text{'chain_edup'});
    }
} else {
    $table->{'chains'}->{$name} || error($text{'chain_nochain'});
}

if ($is_rename) {
    if ($name eq $old) {
        redirect("index.cgi?table=$in{'table'}");
        return;
    }
    if ($name ne $old) {
        $table->{'chains'}->{$name} = $table->{'chains'}->{$old};
        delete($table->{'chains'}->{$old});

        foreach my $r (@{$table->{'rules'}}) {
            $r->{'chain'} = $name if ($r->{'chain'} && $r->{'chain'} eq $old);
            my $changed = 0;
            if ($r->{'jump'} && $r->{'jump'} eq $old) {
                $r->{'jump'} = $name;
                $changed = 1;
            }
            if ($r->{'goto'} && $r->{'goto'} eq $old) {
                $r->{'goto'} = $name;
                $changed = 1;
            }
            $r->{'text'} = format_rule_text($r) if ($changed);
        }
    }

    my $err = save_table_configuration($table, @tables);
    error(text('rename_chain_failed', $err)) if ($err);
    webmin_log("rename", "chain", $old,
                { 'new' => $name,
                  'table' => $table->{'name'},
                  'family' => $table->{'family'} });
    redirect("index.cgi?table=$in{'table'}");
    return;
}

my $type = $in{'chain_type'};
my $hook = $in{'chain_hook'};
my $priority = $in{'chain_priority'};
my $policy = $in{'chain_policy'};

for my $v (\$type, \$hook, \$priority, \$policy) {
    $$v =~ s/^\s+// if (defined($$v));
    $$v =~ s/\s+$// if (defined($$v));
}
$type = undef if (!defined($type) || $type eq '');
$hook = undef if (!defined($hook) || $hook eq '');
$priority = undef if (!defined($priority) || $priority eq '');
$policy = undef if (!defined($policy) || $policy eq '');

validate_chain_base($type, $hook, $priority, $policy) ||
    error($text{'chain_ebase'});

my $chain = $table->{'chains'}->{$name} || { };
$chain->{'type'} = $type;
$chain->{'hook'} = $hook;
$chain->{'priority'} = $priority;
$chain->{'policy'} = $policy;
$table->{'chains'}->{$name} = $chain;

my $err = save_table_configuration($table, @tables);
error(text('chain_failed', $err)) if ($err);

webmin_log($is_new ? "create" : "modify", "chain", $name,
            { 'table' => $table->{'name'}, 'family' => $table->{'family'} });
redirect("index.cgi?table=$in{'table'}");
