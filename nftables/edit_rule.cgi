#!/usr/bin/perl
# edit_rule.cgi
# Display a form for creating or editing a rule

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text, %config);
ReadParse();
assert_acl('rules');
my $can_edit_raw = check_acl('raw');
my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'move_notable'});
assert_table_acl($table);
my $rule;
my $chain_def;
my $chain_hook;
my $action_sel;
my $proto_sel;
my $icmp_type;
my $log_enabled;
my $raw_extra = "";
my $ct_state_sel;
my $tcp_flags_sel;
my $advanced_open;
my $saddr_set;
my $daddr_set;
my $sport_set;
my $dport_set;
my $saddr_val;
my $daddr_val;
my $sport_val;
my $dport_val;
my @addr_set_opts;
my @port_set_opts;
my %set_families;

sub split_multi_value
{
    my ($v) = @_;
    return if (!defined($v) || $v eq '');
    $v =~ s/^\s*\{//;
    $v =~ s/\}\s*$//;
    $v =~ s/^\s+//;
    $v =~ s/\s+$//;
    return if ($v eq '');
    my @vals = split(/\s*,\s*/, $v);
    @vals = grep { $_ ne '' } @vals;
    return \@vals;
}

if ($in{'new'}) {
    ui_print_header(undef, $text{'edit_title_new'}, "", "intro", 1, 1);
    $rule = { 'chain' => $in{'chain'} };
} else {
    ui_print_header(undef, $text{'edit_title_edit'}, "", "intro", 1, 1);
    $rule = $table->{'rules'}->[$in{'idx'}];
}
if ($table && $rule->{'chain'}) {
    $chain_def = $table->{'chains'}->{$rule->{'chain'}};
    $chain_hook = $chain_def ? $chain_def->{'hook'} : undef;
}
if ($rule) {
    if ($rule->{'exprs'} && ref($rule->{'exprs'}) eq 'ARRAY') {
        my @raw = map { $_->{'text'} }
                  grep { $_->{'type'} && $_->{'type'} eq 'raw' }
                  @{$rule->{'exprs'}};
        $raw_extra = join(" ", @raw);
    }
    if ($rule->{'jump'}) {
        $action_sel = 'jump';
    }
    elsif ($rule->{'goto'}) {
        $action_sel = 'goto';
    }
    else {
        $action_sel = $rule->{'action'};
    }
    $action_sel ||= 'accept';
    $proto_sel = $rule->{'proto'} || $rule->{'l4proto'};
    if (!$proto_sel) {
        $proto_sel = 'icmp' if ($rule->{'icmp_type'});
        $proto_sel = 'icmpv6' if ($rule->{'icmpv6_type'});
    }
    $proto_sel ||= 'tcp' if ($in{'new'});
    $icmp_type = $rule->{'icmp_type'} || $rule->{'icmpv6_type'};
    $ct_state_sel = split_multi_value($rule->{'ct_state'});
    $tcp_flags_sel = split_multi_value($rule->{'tcp_flags'});
    $log_enabled = $rule->{'log'} || $rule->{'log_prefix'} || $rule->{'log_level'};
}
$saddr_set = set_name_from_value($rule->{'saddr'});
$daddr_set = set_name_from_value($rule->{'daddr'});
$sport_set = set_name_from_value($rule->{'sport'});
$dport_set = set_name_from_value($rule->{'dport'});
$saddr_val = $saddr_set ? "" : $rule->{'saddr'};
$daddr_val = $daddr_set ? "" : $rule->{'daddr'};
$sport_val = $sport_set ? "" : $rule->{'sport'};
$dport_val = $dport_set ? "" : $rule->{'dport'};

@addr_set_opts = ( [ "", $text{'edit_set_none'} ] );
@port_set_opts = ( [ "", $text{'edit_set_none'} ] );
my %addr_set_seen;
my %port_set_seen;
if ($table && $table->{'sets'} && ref($table->{'sets'}) eq 'HASH') {
    foreach my $s (sort keys %{$table->{'sets'}}) {
        my $set = $table->{'sets'}->{$s} || { };
        my $label = $s;
        $label .= " ($set->{'type'})" if ($set->{'type'});
        my $kind = set_type_kind($set->{'type'});
        if ($kind && $kind eq 'addr') {
            push(@addr_set_opts, [ $s, $label ]);
            $addr_set_seen{$s} = 1;
        }
        if ($kind && $kind eq 'port') {
            push(@port_set_opts, [ $s, $label ]);
            $port_set_seen{$s} = 1;
        }
        my $fam = set_type_family($set->{'type'});
        $set_families{$s} = $fam if ($fam);
    }
}
if ($saddr_set && !$addr_set_seen{$saddr_set}) {
    push(@addr_set_opts, [ $saddr_set, $saddr_set ]);
}
if ($daddr_set && !$addr_set_seen{$daddr_set}) {
    push(@addr_set_opts, [ $daddr_set, $daddr_set ]);
}
if ($sport_set && !$port_set_seen{$sport_set}) {
    push(@port_set_opts, [ $sport_set, $sport_set ]);
}
if ($dport_set && !$port_set_seen{$dport_set}) {
    push(@port_set_opts, [ $dport_set, $dport_set ]);
}
$advanced_open = 1 if ($action_sel && ($action_sel eq 'jump' || $action_sel eq 'goto'));
$advanced_open = 1 if ($rule && (
    $rule->{'jump'} || $rule->{'goto'} ||
    $rule->{'iif'} || $rule->{'oif'} ||
    $icmp_type ||
    $rule->{'ct_state'} ||
    $rule->{'tcp_flags'} || $rule->{'tcp_flags_mask'} ||
    $rule->{'limit_rate'} || $rule->{'limit_burst'} ||
    $log_enabled ||
    $rule->{'counter'}
));

my @icmp_types = qw(
    echo-reply destination-unreachable source-quench redirect echo-request
    router-advertisement router-solicitation time-exceeded parameter-problem
    timestamp-request timestamp-reply info-request info-reply
    address-mask-request address-mask-reply
);
my @icmpv6_types = qw(
    destination-unreachable packet-too-big time-exceeded parameter-problem
    echo-request echo-reply mld-listener-query mld-listener-report
    mld-listener-done mld-listener-reduction nd-router-solicit
    nd-router-advert nd-neighbor-solicit nd-neighbor-advert nd-redirect
    router-renumbering ind-neighbor-solicit ind-neighbor-advert
    mld2-listener-report
);
my %icmp_seen;
my @icmp_type_opts = ( [ "", $text{'edit_proto_any'} ] );
foreach my $t (@icmp_types, @icmpv6_types) {
    next if ($icmp_seen{$t}++);
    push(@icmp_type_opts, [ $t, $t ]);
}
my @ct_state_opts = (
    [ "", $text{'edit_proto_any'} ],
    map { [ $_, $_ ] } qw(invalid new established related untracked),
);
my @tcp_flags_opts = (
    [ "", $text{'edit_proto_any'} ],
    map { [ $_, $_ ] } qw(fin syn rst psh ack urg ecn cwr),
);

print ui_form_start("save_rule.cgi");
print ui_hidden("table", $in{'table'});
print ui_hidden("idx", $in{'idx'});
print ui_hidden("chain", $rule->{'chain'});
print ui_hidden("new", $in{'new'});
print ui_hidden("raw_extra", $raw_extra);

print ui_table_start($text{'edit_header'}, "width=100%", 2);

# Rule comment
print ui_table_row(hlink($text{'edit_comment'}, "comment"),
    ui_textbox("comment", $rule->{'comment'}, 50));

# Action
print ui_table_row(hlink($text{'edit_action'}, "action"),
    ui_select("action", $action_sel,
    [
        [ "accept", $text{'index_accept'} ],
        [ "drop", $text{'index_drop'} ],
        [ "reject", $text{'index_reject'} ],
        [ "return", $text{'edit_return'} ],
        [ "jump", $text{'edit_jump_action'} ],
        [ "goto", $text{'edit_goto_action'} ],
    ]));

# Addresses
my $saddr_row = ui_textbox("saddr", $saddr_val, 30);
if (@addr_set_opts > 1) {
    $saddr_row .= "<br>".text('edit_saddr_set',
                               ui_select("saddr_set", $saddr_set, \@addr_set_opts, 1, 0, 1));
}
print ui_table_row(hlink($text{'edit_saddr'}, "saddr"), $saddr_row);

my $daddr_row = ui_textbox("daddr", $daddr_val, 30);
if (@addr_set_opts > 1) {
    $daddr_row .= "<br>".text('edit_daddr_set',
                               ui_select("daddr_set", $daddr_set, \@addr_set_opts, 1, 0, 1));
}
print ui_table_row(hlink($text{'edit_daddr'}, "daddr"), $daddr_row);

# Protocol
print ui_table_row(hlink($text{'edit_proto'}, "proto"),
    ui_select("proto", $proto_sel,
    [
        [ "", $text{'edit_proto_any'} ],
        [ "tcp", "TCP" ],
        [ "udp", "UDP" ],
        [ "icmp", "ICMP" ],
        [ "icmpv6", "ICMPv6" ],
    ]));

# Ports
my $sport_row = ui_textbox("sport", $sport_val, 10);
if (@port_set_opts > 1) {
    $sport_row .= "<br>".text('edit_sport_set',
                               ui_select("sport_set", $sport_set, \@port_set_opts, 1, 0, 1));
}
print ui_table_row(hlink($text{'edit_sport'}, "sport"), $sport_row);

my $dport_row = ui_textbox("dport", $dport_val, 10);
if (@port_set_opts > 1) {
    $dport_row .= "<br>".text('edit_dport_set',
                               ui_select("dport_set", $dport_set, \@port_set_opts, 1, 0, 1));
}
print ui_table_row(hlink($text{'edit_dport'}, "dport"), $dport_row);
print ui_table_row(undef, ui_note($text{'edit_ports_note'}, 0), 2);

print ui_table_end();

print ui_hidden_table_start($text{'edit_advanced'}, "width=100%", 2,
                             "advanced", $advanced_open ? 1 : 0);

# Jump/Goto target chain
print ui_table_row(hlink($text{'edit_jump'}, "jump"),
    ui_textbox("jump", $rule->{'jump'}, 20));
print ui_table_row(hlink($text{'edit_goto'}, "goto"),
    ui_textbox("goto", $rule->{'goto'}, 20));

# Interfaces
if ($chain_hook && $chain_hook eq 'input') {
    # Incoming interface
    print ui_table_row(hlink($text{'edit_iif'}, "iif"),
        interface_choice("iif", $rule->{'iif'}, $text{'edit_if_any'}));
}
elsif ($chain_hook && $chain_hook eq 'output') {
    # Outgoing interface
    print ui_table_row(hlink($text{'edit_oif'}, "oif"),
        interface_choice("oif", $rule->{'oif'}, $text{'edit_if_any'}));
}
else {
    # Forward or unknown chain - allow both
    print ui_table_row(hlink($text{'edit_iif'}, "iif"),
        interface_choice("iif", $rule->{'iif'}, $text{'edit_if_any'}));
    print ui_table_row(hlink($text{'edit_oif'}, "oif"),
        interface_choice("oif", $rule->{'oif'}, $text{'edit_if_any'}));
}

# ICMP type
print ui_table_row(hlink($text{'edit_icmp_type'}, "icmp_type"),
    ui_select("icmp_type", $icmp_type, \@icmp_type_opts, 1, 0, 1));

# Conntrack state
print ui_table_row(hlink($text{'edit_ct_state'}, "ct_state"),
    ui_select("ct_state", $ct_state_sel, \@ct_state_opts, 5, 1, 1));

# TCP flags
print ui_table_row(hlink($text{'edit_tcp_flags'}, "tcp_flags"),
    ui_select("tcp_flags", $tcp_flags_sel, \@tcp_flags_opts, 8, 1, 1));
print ui_table_row(hlink($text{'edit_tcp_flags_mask'}, "tcp_flags_mask"),
    ui_textbox("tcp_flags_mask", $rule->{'tcp_flags_mask'}, 20));

# Limit
print ui_table_row(hlink($text{'edit_limit_rate'}, "limit_rate"),
    ui_textbox("limit_rate", $rule->{'limit_rate'}, 20));
print ui_table_row(hlink($text{'edit_limit_burst'}, "limit_burst"),
    ui_textbox("limit_burst", $rule->{'limit_burst'}, 10));

# Log
my $log_row = ui_checkbox("log", 1, hlink($text{'edit_log_enable'}, "log_enable"), $log_enabled);
$log_row .= "<br>".text('edit_log_prefix', ui_textbox("log_prefix", $rule->{'log_prefix'}, 20));
$log_row .= " ".text('edit_log_level', ui_textbox("log_level", $rule->{'log_level'}, 10));
print ui_table_row($text{'edit_log'}, $log_row);

# Counter
print ui_table_row(hlink($text{'edit_counter'}, "counter"),
    ui_checkbox("counter", 1, $text{'edit_counter_enable'}, $rule->{'counter'}));

print ui_hidden_table_end("advanced");

print ui_table_start($text{'edit_rule'}, "width=100%", 2);

# Raw rule (read-only unless edit direct is checked)
my $raw_controls = $can_edit_raw ?
    ui_checkbox("edit_direct", 1, $text{'edit_raw_rule_direct'}, 0)."<br>" : "";
my $raw_area = ui_textarea("raw_rule", $rule->{'text'}, 4, 60, undef, undef,
                            "readonly='true'");
print ui_table_row(hlink($text{'edit_raw_rule'}, "raw_rule"), $raw_controls.$raw_area,
                    undef, undef, ["data-column-span='all' data-column-locked='1'"]);

print ui_table_end();
my @buttons;
if ($in{'new'}) {
    push(@buttons, [ undef, $text{'create'} ]);
} else {
    push(@buttons, [ undef, $text{'save'} ]);
    push(@buttons, [ 'delete', $text{'delete'} ]);
}
print ui_form_end(\@buttons);

sub js_array
{
    my (@vals) = @_;
    return "[".join(",", map {
        my $v = $_;
        $v =~ s/\\/\\\\/g;
        $v =~ s/"/\\"/g;
        "\"$v\"";
    } @vals)."]";
}

sub js_object
{
    my (%vals) = @_;
    return "{".join(",", map {
        my $k = $_;
        my $v = $vals{$k};
        $k =~ s/\\/\\\\/g;
        $k =~ s/"/\\"/g;
        $v =~ s/\\/\\\\/g if (defined($v));
        $v =~ s/"/\\"/g if (defined($v));
        "\"$k\":\"$v\"";
    } sort keys %vals)."}";
}

my $icmp_js = js_array(@icmp_types);
my $icmpv6_js = js_array(@icmpv6_types);
my $icmp_any = $text{'edit_proto_any'};
$icmp_any =~ s/\\/\\\\/g;
$icmp_any =~ s/"/\\"/g;
my $set_fam_js = js_object(%set_families);

print "<script>\n";
print "(function() {\n";
print "  var icmpTypes = $icmp_js;\n";
print "  var icmpv6Types = $icmpv6_js;\n";
print "  var icmpAnyLabel = \"$icmp_any\";\n";
print "  var setFamilies = $set_fam_js;\n";
print <<'EOF';
  function byName(name) {
    var els = document.getElementsByName(name);
    return els && els.length ? els[0] : null;
  }
  function val(name) {
    var el = byName(name);
    if (!el) return "";
    if (el.tagName === "SELECT" && el.multiple) {
      var vals = [];
      var sawEmpty = false;
      for (var i = 0; i < el.options.length; i++) {
        var opt = el.options[i];
        if (opt.selected) {
          if (opt.value === "") sawEmpty = true;
          else vals.push(opt.value);
        }
      }
      if (vals.length && sawEmpty) {
        for (var j = 0; j < el.options.length; j++) {
          if (el.options[j].value === "") el.options[j].selected = false;
        }
      }
      return vals.join(",");
    }
    if (el.type === "checkbox") {
      return el.checked ? (el.value || "1") : "";
    }
    return el.value || "";
  }
  function ifaceVal(name) {
    var v = val(name);
    if (v === "other") {
      return val(name + "_other");
    }
    return v;
  }
  function escapeNft(s) {
    return s.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
  }
  function isNumeric(s) {
    return /^[0-9]+$/.test(s);
  }
  function guessFamily(addr) {
    return addr.indexOf(":") >= 0 ? "ip6" : "ip";
  }
  function familyForSet(name) {
    return setFamilies && setFamilies[name] ? setFamilies[name] : "";
  }
  function familyForValue(val) {
    if (!val) return "";
    if (val.charAt(0) === "@") {
      var fam = familyForSet(val.substr(1));
      if (fam) return fam;
    }
    return guessFamily(val);
  }
  function buildRule() {
    var direct = byName("edit_direct");
    if (direct && direct.checked) return;
    var parts = [];

    var iif = ifaceVal("iif");
    if (iif) parts.push("iif \"" + escapeNft(iif) + "\"");
    var oif = ifaceVal("oif");
    if (oif) parts.push("oif \"" + escapeNft(oif) + "\"");

    var saddrSet = val("saddr_set");
    var saddr = val("saddr");
    if (saddrSet) {
      var sf = familyForSet(saddrSet) || guessFamily("@" + saddrSet);
      parts.push(sf + " saddr @" + saddrSet);
    } else if (saddr) {
      parts.push(familyForValue(saddr) + " saddr " + saddr);
    }
    var daddrSet = val("daddr_set");
    var daddr = val("daddr");
    if (daddrSet) {
      var df = familyForSet(daddrSet) || guessFamily("@" + daddrSet);
      parts.push(df + " daddr @" + daddrSet);
    } else if (daddr) {
      parts.push(familyForValue(daddr) + " daddr " + daddr);
    }

    var proto = val("proto");
    var sportSet = val("sport_set");
    var dportSet = val("dport_set");
    var sport = sportSet ? ("@" + sportSet) : val("sport");
    var dport = dportSet ? ("@" + dportSet) : val("dport");
    var icmpType = val("icmp_type");
    if (!proto && (sport || dport)) {
      proto = "tcp";
    }

    var l4proto = "";
    var portProto = "";
    if (proto && (proto === "tcp" || proto === "udp")) {
      portProto = proto;
      if (!sport && !dport) {
        l4proto = proto;
      }
    }
    else if (proto) {
      l4proto = proto;
    }
    if (l4proto) {
      parts.push("meta l4proto " + l4proto);
    }
    if (sport && portProto) parts.push(portProto + " sport " + sport);
    if (dport && portProto) parts.push(portProto + " dport " + dport);

    if (proto === "icmp" && icmpType) parts.push("icmp type " + icmpType);
    if (proto === "icmpv6" && icmpType) parts.push("icmpv6 type " + icmpType);
    if (!proto && icmpType) {
      var inIcmp = icmpTypes.indexOf(icmpType) >= 0;
      var inIcmpv6 = icmpv6Types.indexOf(icmpType) >= 0;
      if (inIcmpv6 && !inIcmp) {
        parts.push("meta l4proto icmpv6");
        parts.push("icmpv6 type " + icmpType);
      } else {
        parts.push("meta l4proto icmp");
        parts.push("icmp type " + icmpType);
      }
    }

    var tcpFlags = val("tcp_flags");
    var tcpMask = val("tcp_flags_mask");
    if (tcpFlags) {
      if (tcpMask) parts.push("tcp flags & " + tcpMask + " == " + tcpFlags);
      else parts.push("tcp flags " + tcpFlags);
    }

    var ctState = val("ct_state");
    if (ctState) parts.push("ct state " + ctState);

    var limitRate = val("limit_rate");
    var limitBurst = val("limit_burst");
    if (limitRate) {
      var lim = "limit rate " + limitRate;
      if (limitBurst) {
        lim += " burst " + limitBurst;
        if (isNumeric(limitBurst)) lim += " packets";
      }
      parts.push(lim);
    }

    var logBox = byName("log");
    var logEnabled = logBox && logBox.checked;
    var logPrefix = val("log_prefix");
    var logLevel = val("log_level");
    if (logEnabled || logPrefix || logLevel) {
      var lp = ["log"];
      if (logPrefix) lp.push("prefix \"" + escapeNft(logPrefix) + "\"");
      if (logLevel) lp.push("level " + logLevel);
      parts.push(lp.join(" "));
    }

    var counter = byName("counter");
    if (counter && counter.checked) parts.push("counter");

    var action = val("action");
    var jump = val("jump");
    var go = val("goto");
    if (action === "jump" && jump) parts.push("jump " + jump);
    else if (action === "goto" && go) parts.push("goto " + go);
    else if (action && action !== "jump" && action !== "goto") parts.push(action);

    var comment = val("comment");
    if (comment) parts.push("comment \"" + escapeNft(comment) + "\"");

    var extra = val("raw_extra");
    if (extra) parts.push(extra);

    var raw = parts.join(" ").replace(/^\s+|\s+$/g, "");
    var rawEl = byName("raw_rule");
    if (rawEl) rawEl.value = raw;
  }

  function toggleDirect() {
    var direct = byName("edit_direct");
    var on = direct && direct.checked;
    var form = direct ? direct.form : document.forms[0];
    if (!form) return;
    var els = form.querySelectorAll("input, select, textarea");
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      if (el.name === "edit_direct" || el.name === "raw_rule") continue;
      if (el.type === "hidden" || el.type === "submit" || el.type === "button") continue;
      el.disabled = on;
    }
    var rawEl = byName("raw_rule");
    if (rawEl) rawEl.readOnly = !on;
    if (!on) buildRule();
  }

  function uniqList(list) {
    var seen = {};
    var out = [];
    for (var i = 0; i < list.length; i++) {
      var v = list[i];
      if (seen[v]) continue;
      seen[v] = true;
      out.push(v);
    }
    return out;
  }

  function updateIcmpTypes() {
    var el = byName("icmp_type");
    if (!el) return;
    var proto = val("proto");
    var current = el.value || "";
    var list;
    if (proto === "icmp") list = icmpTypes;
    else if (proto === "icmpv6") list = icmpv6Types;
    else list = uniqList(icmpTypes.concat(icmpv6Types));

    while (el.options.length) {
      el.remove(0);
    }
    var optAny = document.createElement("option");
    optAny.value = "";
    optAny.text = icmpAnyLabel;
    el.add(optAny);
    for (var i = 0; i < list.length; i++) {
      var opt = document.createElement("option");
      opt.value = list[i];
      opt.text = list[i];
      el.add(opt);
    }
    if (current && list.indexOf(current) >= 0) el.value = current;
    else el.value = "";
  }

  function maybeSetProtoFromIcmp() {
    var protoEl = byName("proto");
    if (!protoEl || protoEl.value) return;
    var t = val("icmp_type");
    if (!t) return;
    var inIcmp = icmpTypes.indexOf(t) >= 0;
    var inIcmpv6 = icmpv6Types.indexOf(t) >= 0;
    if (inIcmp && !inIcmpv6) protoEl.value = "icmp";
    else if (inIcmpv6 && !inIcmp) protoEl.value = "icmpv6";
    if (protoEl.value) updateIcmpTypes();
  }

  function bind() {
    var direct = byName("edit_direct");
    var form = direct ? direct.form : document.forms[0];
    if (!form) return;
    var els = form.querySelectorAll("input, select, textarea");
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      if (el.name === "raw_rule") continue;
      if (el.name === "edit_direct") {
        el.addEventListener("change", toggleDirect);
        continue;
      }
      if (el.name === "proto") {
        el.addEventListener("change", function() {
          updateIcmpTypes();
          buildRule();
        });
        continue;
      }
      if (el.name === "icmp_type") {
        el.addEventListener("change", function() {
          maybeSetProtoFromIcmp();
          buildRule();
        });
        continue;
      }
      el.addEventListener("input", buildRule);
      el.addEventListener("change", buildRule);
    }
    updateIcmpTypes();
    toggleDirect();
    buildRule();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bind);
  } else {
    bind();
  }
})();
</script>
EOF

ui_print_footer("index.cgi?table=$in{'table'}", $text{'index_return'});
