#!/usr/local/bin/perl
# Edit or create a Kea shared network.

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
my $shareds = &kea_shared_networks($root);
&error($text{'shared_enone'})
	if (!$in{'new'} && (!defined($in{'idx'}) || $in{'idx'} !~ /^\d+$/));
my $shared = $in{'new'} ? { } : $shareds->[$in{'idx'}];
&error($text{'shared_enone'}) if (!$shared);

# Shared networks are containers for same-link subnets. New shared networks do
# not show the Subnets tab until they have a stable index to attach subnets to.
my $title = $in{'new'} ? $text{'shared_create'} : $text{'shared_edit'};
&ui_print_header(undef, $title, "", undef, 1, 1);
print &kea_comment_loss_warning($c);
print &ui_form_start("save_shared.cgi", "post");
print &ui_hidden("version", $ver);
print &ui_hidden("new", 1) if ($in{'new'});
print &ui_hidden("idx", $in{'idx'}) if (!$in{'new'});

my @tabs = (
	[ 'general', $text{'tab_general'} ],
	[ 'options', $text{'tab_options'} ],
	[ 'advanced', $text{'tab_advanced'} ],
	);
splice(@tabs, 1, 0, [ 'subnets', $text{'tab_subnets'} ])
	if (!$in{'new'});
my $mode = $in{'mode'} || "general";
$mode = "general" if ($in{'new'} && $mode eq "subnets");
print &ui_tabs_start(\@tabs, "mode", $mode, 1);

# General data identifies the shared network and optionally scopes it to an
# interface or relay address used by Kea during subnet selection.
print &ui_tabs_start_tab("mode", "general");
print &ui_div($text{'shared_general_desc'});
print &ui_table_start($text{'shared_general'}, "width=100%", 4);
print &ui_table_row(&kea_field_hlink('shared-network-name',
				     $text{'shared_name'}),
	&ui_textbox("name", $shared->{'name'} || "", 40));
print &ui_table_row(&kea_field_hlink('description', $text{'shared_desc'}),
	&ui_textbox("desc", &kea_get_comment($shared) || "", 60));
print &ui_table_row(&kea_field_hlink('interface'),
	&ui_textbox("interface", $shared->{'interface'} || "", 30));
print &ui_table_row(&kea_field_hlink('relay_ip_addresses'),
	&ui_textbox("relay_ip_addresses",
		    join(" ", &kea_relay_addresses($shared)), 50));
print &ui_table_end();
print &ui_tabs_end_tab("mode", "general");

if (!$in{'new'}) {
	# Existing shared networks can show their member subnets and provide a
	# shortcut for creating a subnet directly under this parent.
	print &ui_tabs_start_tab("mode", "subnets");
	print &ui_div($text{'shared_subnets_desc'});
	my $subs = &kea_subnet_list($root, $ver, $in{'idx'});
	print &ui_columns_start([
	$text{'col_id'}, $text{'col_subnet'}, $text{'col_pools'},
	$text{'col_reservations'}, $text{'col_options'} ], 100);
for(my $i=0; $i<@$subs; $i++) {
	my $s = $subs->[$i];
	print &ui_columns_row([
		$s->{'id'} || "",
		&ui_link("edit_subnet.cgi?version=$ver&sidx=$in{'idx'}&idx=$i",
			 &html_escape($s->{'subnet'} || "")),
		&kea_count_array($s, 'pools'),
		&kea_count_array($s, 'reservations'),
		&kea_count_array($s, 'option-data'),
		]);
	}
print &ui_columns_row([ &ui_tag('i', &html_escape($text{'index_empty'})) ],
		       [ "colspan=5" ])
	if (!@$subs);
print &ui_columns_end();
print &ui_link_button("edit_subnet.cgi?version=$ver&sidx=$in{'idx'}&new=1",
		      $text{'index_add_subnet'});
print &ui_tabs_end_tab("mode", "subnets");
}

# Shared-network options are inherited by subnets unless a more specific scope
# overrides them.
print &ui_tabs_start_tab("mode", "options");
print &ui_div($text{'shared_options_desc'});
&kea_common_option_rows($shared->{'option-data'}, $ver, "common_");
&kea_option_data_section($shared->{'option-data'}, "opt_", $ver);
print &ui_tabs_end_tab("mode", "options");

# Advanced shared-network settings mirror Kea fields that affect all member
# subnets, including timers and protocol-specific behavior flags.
print &ui_tabs_start_tab("mode", "advanced");
print &ui_div($text{'shared_advanced_desc'});
print &ui_table_start($text{'shared_advanced'}, "width=100%", 4);
if ($ver == 4) {
	print &ui_table_row(&kea_field_hlink('authoritative'),
		&ui_select("authoritative", &kea_bool_value($shared->{'authoritative'}),
			[ [ "", $text{'inherit_default'} ],
			  [ "true", $text{'yes'} ],
			  [ "false", $text{'no'} ] ]));
	}
foreach my $k ('renew-timer', 'rebind-timer', 'valid-lifetime',
	       'min-valid-lifetime', 'max-valid-lifetime') {
	print &ui_table_row(&kea_field_hlink($k),
		&ui_textbox($k, defined($shared->{$k}) ? $shared->{$k} : "", 12));
	}
print &ui_table_row(&kea_field_hlink('preferred-lifetime'),
	&ui_textbox("preferred-lifetime",
		    defined($shared->{'preferred-lifetime'}) ? $shared->{'preferred-lifetime'} : "", 12))
	if ($ver == 6);
&kea_advanced_option_rows($shared->{'option-data'}, $ver, "adv_");
print &ui_table_end();
print &ui_tabs_end_tab("mode", "advanced");

print &ui_tabs_end();

my @buttons = $in{'new'} ? ([ "save", $text{'create'} ]) :
			    ([ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ]);
print &ui_form_end(\@buttons);
&ui_print_footer("", $text{'index_return'});
