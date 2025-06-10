#!/usr/local/bin/perl
# edit_pool.cgi
# A form for editing or creating a delay pool

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
&ReadParse();
$access{'delay'} || &error($text{'delay_ecannot'});
my $conf = &get_config();

my $pool;
my @access;
my $param;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'pool_title1'}, "", "edit_pool", 0, 0, 0,
		&restart_button());
	$pool = { 'values' => [] };
	$param = { 'values' => [] };
	}
else {
	&ui_print_header(undef, $text{'pool_title2'}, "", "edit_pool", 0, 0, 0,
		&restart_button());
	my @pools = &find_config("delay_class", $conf);
	($pool) = grep { $_->{'values'}->[0] == $in{'idx'} } @pools;
	my @params = &find_config("delay_parameters", $conf);
	($param) = grep { $_->{'values'}->[0] == $in{'idx'} } @params;
	@access = &find_config("delay_access", $conf);
	@access = grep { $_->{'values'}->[0] == $in{'idx'} } @access;
	}

print &ui_form_start("save_pool.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'pool_header'}, "width=100%", 2);

if ($in{'new'}) {
	my $pools = &find_value("delay_pools", $conf);
	print &ui_table_row($text{'pool_num'}, $pools + 1);
	}
else {
	print &ui_table_row($text{'pool_num'}, $in{'idx'});
	}

my $cls = $pool->{'values'}->[1] || 1;
print &ui_table_row($text{'pool_class'},
	&ui_select("class", $cls,
		[ map { [ $_, $_." - ".$text{"delay_class_".$_} ] }
		      (1 .. ($squid_version >= 3 ? 5 : 3)) ]));

print &ui_table_row($text{'pool_agg'},
	&limit_field("agg", $cls == 5 ? undef : $param->{'values'}->[1]), 3);

print &ui_table_row($text{'pool_ind'},
	&limit_field("ind", $param->{'values'}->[$cls == 2 ? 2 : 3]), 3);

print &ui_table_row($text{'pool_net'},
	&limit_field("net", $cls == 3 || $cls == 4 ?
				$param->{'values'}->[2] : undef), 3);

if ($squid_version >= 3) {
	print &ui_table_row($text{'pool_user'},
		&limit_field("user", $cls == 4 ?
			$param->{'values'}->[4] : undef), 3);

	print &ui_table_row($text{'pool_tag'},
		&limit_field("tag", $cls == 5 ?
			$param->{'values'}->[1] : undef), 3);

	}

print &ui_table_end();

if (!$in{'new'}) {
	print &ui_subheading($text{'pool_aclheader'});

	if (@access) {
		my $table = &ui_columns_start([
				$text{'eacl_act'},
				$text{'eacl_acls1'},
				$text{'eacl_move'},
				], 100, 0, [ undef, undef, "width=5%" ]);
		my $hc = 0;
		foreach my $h (@access) {
			my @v = @{$h->{'values'}};
			if ($v[1] eq "allow") {
				$v[1] = $text{'eacl_allow'};
				}
			else {
				$v[1] = $text{'eacl_deny'};
				}
			my $mover = &ui_up_down_arrows(
				"move_pool.cgi?$hc+-1",
				"move_pool.cgi?$hc+1",
				$hc != 0,
				$hc != @access-1
				);
			$table .= &ui_columns_row([
				&ui_link("pool_access.cgi?index=".
					   "$h->{'index'}&idx=$in{'idx'}",
					 $v[1]),
				&html_escape(join(' ', @v[2..$#v])),
				$mover,
				]);
			$hc++;
			}
		$table .= &ui_columns_end();
		print $table;
		}
	else {
		print "<b>$text{'pool_noacl'}</b><p>\n";
		}
	print &ui_links_row([ &ui_link("pool_access.cgi?new=1&idx=$in{'idx'}",
				       $text{'pool_add'}) ]);
	}
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("edit_delay.cgi", $text{'delay_return'},
	"", $text{'index_return'});

# limit_field(name, value)
sub limit_field
{
my ($name, $value) = @_;
my ($v1, $v2) = $value =~ /^([0-9\-]+)\/([0-9\-]+)$/ ? ($1, $2) : ( -1, -1 );
my $unl = $v1 == -1 && $v2 == -1;
return &ui_radio($name."_def", $unl ? 1 : 0,
		   [ [ 1, $text{'delay_unlimited'} ],
		     [ 0, &unit_field($name."_1", $unl ? "" : $v1).
			  $text{'pool_limit1'}."&nbsp;&nbsp;".
			  &unit_field($name."_2", $unl ? "" : $v2).
			  $text{'pool_limit2'} ] ]);
}

# unit_field(name, value)
sub unit_field
{
my ($name, $value) = @_;
my @ud = ( .125, 1, 125, 1000, 125000, 1000000 );
my $u;
if ($value > 0) {
	for($u=@ud-1; $u>=1; $u--) {
		last if (!($value%$ud[$u]));
		}
	}
else {
	$u = 1;
	}
return &ui_textbox($name."_n", $value > 0 ? $value/$ud[$u] : $value, 8)." ".
       &ui_select($name."_u", $u,
		  [ map { [ $_, $text{'pool_unit'.$_} ] } (0..$#ud) ]);
}
