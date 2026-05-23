#!/usr/local/bin/perl
# Edit or create a Kea subnet.

use strict;
use warnings;
require './kea-dhcp-lib.pl';
&ReadParse();
our (%in, %text);
&error_setup($text{'eacl_aviol'});

my $ver = $in{'version'} == 6 ? 6 : 4;
&kea_assert_acl('edit'.$ver);
my ($c, $root, $data, $err) = &kea_read_dhcp_config($ver);
&error($err) if ($err);
my $sidx = defined($in{'sidx'}) ? $in{'sidx'} : "";
&error($text{'subnet_enone'}) if (!&kea_valid_subnet_parent($root, $sidx));
&error($text{'subnet_enone'})
	if (!$in{'new'} && (!defined($in{'idx'}) || $in{'idx'} !~ /^\d+$/));
my $sub = $in{'new'} ? { 'id' => &kea_next_subnet_id($root, $ver) }
		      : &kea_get_subnet($root, $ver, $sidx, $in{'idx'});
&error($text{'subnet_enone'}) if (!$sub);

# Main request flow: render the tabbed subnet editor, then delegate repeated
# row-heavy controls to helpers below.
my $title = $in{'new'} ? $text{'subnet_create'} : $text{'subnet_edit'};
&ui_print_header(undef, $title, "", undef, 1, 1);
print &kea_comment_loss_warning($c);
print &ui_form_start("save_subnet.cgi", "post");
print &ui_hidden("version", $ver);
print &ui_hidden("new", 1) if ($in{'new'});
print &ui_hidden("idx", $in{'idx'}) if (!$in{'new'});
print &ui_hidden("sidx", $sidx) if ($sidx ne '');

my @tabs = (
	[ 'general', $text{'tab_general'} ],
	[ 'pools', $text{'tab_pools'} ],
	[ 'reservations', $text{'tab_reservations'} ],
	[ 'options', $text{'tab_options'} ],
	[ 'advanced', $text{'tab_advanced'} ],
	);
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "general", 1);

# General owns the required subnet identity plus the parent shared-network
# pointer, which determines where the subnet is stored in Kea JSON.
print &ui_tabs_start_tab("mode", "general");
print &ui_div($text{'subnet_general_desc'});
print &ui_table_start($text{'subnet_general'}, "width=100%", 4);
print &ui_table_row(&kea_field_hlink('subnet-id', $text{'subnet_id'}),
	&ui_textbox("id", $sub->{'id'} || "", 8));
print &ui_table_row(&kea_field_hlink('subnet-prefix',
				     $text{'subnet_prefix'}),
	&ui_textbox("subnet", $sub->{'subnet'} || "", 40));
print &ui_table_row(&kea_field_hlink('calculated-subnet-mask',
				     $text{'subnet_mask_auto'}),
	&ui_tag('tt', &html_escape(&kea_ipv4_mask_from_subnet($sub->{'subnet'} || "")
				   || $text{'index_empty'})))
	if ($ver == 4);
print &ui_table_row(&kea_field_hlink('description', $text{'subnet_desc'}),
	&ui_textbox("desc", &kea_get_comment($sub) || "", 60));

# A subnet may be top-level or nested under a shared network. Kea stores those
# in different arrays, so the selected parent is carried through saves.
my @shared_opts = ([ "", "<$text{'shared_none'}>" ]);
my $shareds = &kea_shared_networks($root);
for(my $i=0; $i<@$shareds; $i++) {
	push(@shared_opts, [ $i, &kea_scope_name($shareds->[$i], &text('index_shared_num', $i+1)) ]);
	}
print &ui_table_row(&kea_field_hlink('shared-network',
					     $text{'subnet_shared'}),
	&ui_select("parent", $sidx ne '' ? $sidx : "", \@shared_opts));
print &ui_table_end();
print &ui_tabs_end_tab("mode", "general");

# Pools are row editors: DHCPv4/DHCPv6 address pools are common, while prefix
# delegation is rendered only for DHCPv6.
print &ui_tabs_start_tab("mode", "pools");
print &ui_div($text{'subnet_pools_desc'});
&pool_rows($sub->{'pools'});
if ($ver == 6) {
	print &ui_subheading($text{'pd_pools'});
	&pd_pool_rows($sub->{'pd-pools'});
	}
print &ui_tabs_end_tab("mode", "pools");

# Reservations stay compact here, but the parser preserves advanced fields that
# the UI does not expose.
print &ui_tabs_start_tab("mode", "reservations");
print &ui_div($text{'subnet_reservations_desc'});
&reservation_rows($sub->{'reservations'}, $ver);
print &ui_tabs_end_tab("mode", "reservations");

# Option editing is split between named common fields and generic option-data
# rows so uncommon options can still round-trip.
print &ui_tabs_start_tab("mode", "options");
print &ui_div($text{'subnet_options_desc'});
&kea_common_option_rows($sub->{'option-data'}, $ver, "common_");
&kea_option_data_section($sub->{'option-data'}, "opt_", $ver);
print &ui_tabs_end_tab("mode", "options");

# Advanced values affect subnet selection, relay matching, lease timing, and
# DHCPv4 boot fields. They are top-level subnet keys, not normal options.
print &ui_tabs_start_tab("mode", "advanced");
print &ui_div($text{'subnet_advanced_desc'});
print &ui_table_start($text{'subnet_advanced'}, "width=100%", 4);
print &ui_table_row(&kea_field_hlink('interface'),
	&ui_textbox("interface", &text_value($sub->{'interface'}), 30));
print &ui_table_row(&kea_field_hlink('relay_ip_addresses'),
	&ui_textbox("relay_ip_addresses",
		    join(" ", &kea_relay_addresses($sub)), 50));
if ($ver == 4) {
	print &ui_table_row(&kea_field_hlink('authoritative'),
		&ui_select("authoritative", &kea_bool_value($sub->{'authoritative'}),
			[ [ "", $text{'inherit_default'} ],
			  [ "true", $text{'yes'} ],
			  [ "false", $text{'no'} ] ]));
	}
foreach my $k ('renew-timer', 'rebind-timer', 'valid-lifetime',
	       'min-valid-lifetime', 'max-valid-lifetime') {
	print &ui_table_row(&kea_field_hlink($k),
		&ui_textbox($k, &text_value($sub->{$k}), 12));
	}
print &ui_table_row(&kea_field_hlink('preferred-lifetime'),
	&ui_textbox("preferred-lifetime", &text_value($sub->{'preferred-lifetime'}), 12))
	if ($ver == 6);
foreach my $k ('next-server', 'server-hostname', 'boot-file-name') {
	print &ui_table_row(&kea_field_hlink($k),
		&ui_textbox($k, &text_value($sub->{$k}), 40))
		    if ($ver == 4);
	}
&kea_advanced_option_rows($sub->{'option-data'}, $ver, "adv_");
print &ui_table_end();
print &ui_tabs_end_tab("mode", "advanced");

print &ui_tabs_end();

my @buttons = $in{'new'} ? ([ "save", $text{'create'} ]) :
			    ([ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ]);
print &ui_form_end(\@buttons);
&ui_print_footer("", $text{'index_return'});

# text_value(value)
# Returns a defined scalar for textboxes without hiding valid zero values.
sub text_value
{
my ($v) = @_;
return defined($v) ? $v : "";
}

# pool_rows(&pools)
# Renders address pools with one extra empty row for adding a pool.
sub pool_rows
{
my ($pools) = @_;
$pools = [ ] if (ref($pools) ne 'ARRAY');
print &ui_table_start($text{'tab_pools'}, "width=100%", 2);

# Always include one empty row so adding a pool does not need a separate
# client-side table mutation.
for(my $i=0; $i<=$#$pools+1; $i++) {
	my $p = $pools->[$i] || { };
	print &ui_table_row(&kea_field_hlink('address-pool',
					     $text{'pool_range'}),
		&ui_textbox("pool_pool_$i", $p->{'pool'} || "", 60));
	}
print &ui_table_end();
}

# pd_pool_rows(&pd-pools)
# Renders DHCPv6 prefix delegation pools with room for one new entry.
sub pd_pool_rows
{
my ($pools) = @_;
$pools = [ ] if (ref($pools) ne 'ARRAY');

# Prefix delegation rows are wider than standard form rows, so keep them in the
# same table wrapper used by generic option-data editors.
print &ui_tag_start('div', { 'class' => 'option-data-table' });
print &ui_columns_start([
	&kea_field_hlink('pd-prefix', $text{'pd_prefix'}),
	&kea_field_hlink('pd-prefix-len', $text{'pd_prefix_len'}),
	&kea_field_hlink('pd-delegated-len', $text{'pd_delegated_len'}),
	&kea_field_hlink('pd-excluded-prefix', $text{'pd_excluded_prefix'}),
	&kea_field_hlink('pd-excluded-prefix-len',
			 $text{'pd_excluded_prefix_len'}) ], 100);
for(my $i=0; $i<=$#$pools+1; $i++) {
	my $p = $pools->[$i] || { };
	print &ui_columns_row([
		&ui_textbox("pd_prefix_$i", $p->{'prefix'} || "", 26),
		&ui_textbox("pd_prefix_len_$i", $p->{'prefix-len'} || "", 5),
		&ui_textbox("pd_delegated_len_$i", $p->{'delegated-len'} || "", 5),
		&ui_textbox("pd_excluded_prefix_$i", $p->{'excluded-prefix'} || "", 26),
		&ui_textbox("pd_excluded_prefix_len_$i", $p->{'excluded-prefix-len'} || "", 5),
		]);
	}
print &ui_columns_end();
print &ui_tag_end('div');
}

# reservation_rows(&reservations, version)
# Renders host reservations without trying to flatten every advanced Kea field.
sub reservation_rows
{
my ($reservations, $ver) = @_;
$reservations = [ ] if (ref($reservations) ne 'ARRAY');

# Kea accepts different reservation identifiers per protocol; the dropdown is
# limited to identifiers that the selected daemon can actually use.
my @types = $ver == 6 ?
	([ 'duid', 'DUID' ], [ 'hw-address', $text{'res_hw'} ],
	 [ 'flex-id', 'Flex ID' ]) :
	([ 'hw-address', $text{'res_hw'} ], [ 'client-id', $text{'res_client'} ],
	 [ 'duid', 'DUID' ], [ 'circuit-id', $text{'res_circuit'} ],
	 [ 'flex-id', 'Flex ID' ]);
my @heads = ( &kea_field_hlink('reservation-identifier-type',
			       $text{'res_type'}),
	      &kea_field_hlink('reservation-identifier',
			       $text{'res_identifier'}),
	      $ver == 6 ?
		&kea_field_hlink('reservation-addresses',
				 $text{'res_addresses'}) :
		&kea_field_hlink('reservation-address',
				 $text{'res_address'}),
	      &kea_field_hlink('reservation-hostname',
			       $text{'res_hostname'}) );
push(@heads, &kea_field_hlink('reservation-prefixes',
			      $text{'res_prefixes'})) if ($ver == 6);
print &ui_tag_start('div', { 'class' => 'option-data-table' });
print &ui_columns_start(\@heads, 100);

# Pick the first identifier field already present, otherwise default to the
# common identifier for the protocol.
for(my $i=0; $i<=$#$reservations+1; $i++) {
	my $r = $reservations->[$i] || { };
	my $rtype = "";
	foreach my $k (map { $_->[0] } @types) {
		if (defined($r->{$k})) {
			$rtype = $k;
			last;
			}
		}
	$rtype ||= $types[0]->[0];
	my $addr = $ver == 6 ? join(" ", @{$r->{'ip-addresses'} || [ ]}) :
			       $r->{'ip-address'};
	my @cols = (
		&ui_select("res_type_$i", $rtype, \@types),
		&ui_textbox("res_identifier_$i", $r->{$rtype} || "", 28),
		&ui_textbox("res_address_$i", $addr || "", 32),
		&ui_textbox("res_hostname_$i", $r->{'hostname'} || "", 22),
		);
	push(@cols, &ui_textbox("res_prefixes_$i",
		join(" ", @{$r->{'prefixes'} || [ ]}), 30)) if ($ver == 6);
	print &ui_columns_row(\@cols);
	}
print &ui_columns_end();
print &ui_tag_end('div');
}
