#!/usr/bin/perl
# edit_chain.cgi
# Display a form for creating or editing a chain

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
assert_acl('chains');

my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'chain_notable'});
assert_table_acl($table);

my $chain = {};
my $chain_name = "";
my $is_new = $in{'new'} ? 1 : 0;

if ($is_new) {
	ui_print_header(undef, $text{'chain_title_new'}, "");
	}
else {
	$chain_name = $in{'chain'};
	$chain = $table->{'chains'}->{$chain_name};
	$chain || error($text{'chain_nochain'});
	ui_print_header(undef, $text{'chain_title_edit'}, "");
	}

my @type_opts = (["", $text{'chain_type_none'}], map { [$_, $_] } qw(filter nat route));
my @hook_opts = (
	["", $text{'chain_hook_none'}],
	map { [$_, $_] } qw(prerouting input forward output postrouting ingress)
);
my @policy_opts = (
	["", $text{'chain_policy_none'}],
	map { [$_, $_] } qw(accept drop reject return queue continue)
);

print ui_form_start("save_chain.cgi");
print ui_hidden("table", $in{'table'});
print ui_hidden("new", $is_new);

print ui_table_start($text{'chain_header'}, "width=100%", 2);

my $name_tags = $is_new ? undef : "readonly";
print ui_table_row(hlink($text{'chain_name'}, "chain_name"),
	ui_textbox("chain_name", $chain_name, 30, 0, undef, $name_tags));

print ui_table_row(
	hlink($text{'chain_type'}, "chain_type"),
	ui_select(
		"chain_type", $chain->{'type'}, \@type_opts, 1, 0, 1, 0,
		"onchange='toggle_chain_base()'"
	)
);
print ui_table_row(hlink($text{'chain_hook'}, "chain_hook"),
	ui_select("chain_hook", $chain->{'hook'}, \@hook_opts, 1, 0, 1));
print ui_table_row(
	hlink($text{'chain_priority'}, "chain_priority"),
	ui_textbox("chain_priority", $chain->{'priority'}, 10)
);
print ui_table_row(hlink($text{'chain_policy'}, "chain_policy"),
	ui_select("chain_policy", $chain->{'policy'}, \@policy_opts, 1, 0, 1));

print ui_table_end();

print ui_form_end([[undef, $text{$is_new ? 'create' : 'save'}]]);

print <<'EOF';
<script>
function toggle_chain_base() {
    var type = document.getElementById('chain_type');
    var disabled = !type || !type.value;
    var ids = ['chain_hook', 'chain_priority', 'chain_policy'];
    for (var i = 0; i < ids.length; i++) {
        var el = document.getElementById(ids[i]);
        if (el) {
            el.disabled = disabled;
        }
    }
}
if (window.addEventListener) {
    window.addEventListener('load', toggle_chain_base);
} else if (window.attachEvent) {
    window.attachEvent('onload', toggle_chain_base);
}
</script>
EOF

ui_print_footer("index.cgi?table=$in{'table'}", $text{'index_return'});
