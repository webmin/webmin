#!/usr/local/bin/perl
# Display an allowed target and IP list

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-target-lib.pl';
our (%text, %in);
&ReadParse();

my $allow = &get_allow_config($in{'mode'});
my $conf = &get_iscsi_config();
my @targets = &find($conf, "Target");

if ($in{'new'}) {
	&ui_print_header(undef, $text{$in{'mode'}.'_title1'}, "");
	$a = { 'addrs' => [ ] };
	}
else {
	&ui_print_header(undef, $text{$in{'mode'}.'_title2'}, "");
	$a = $allow->[$in{'idx'}];
	$a || &error($text{'allow_egone'});
	}

print &ui_form_start("save_allow.cgi", "post");
print &ui_hidden("mode", $in{'mode'});
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{$in{'mode'}.'_header'}, undef, 2);

# Target name
print &ui_table_row($text{'allow_target'},
	&ui_select("name", $a->{'name'},
		   [ [ "ALL", "&lt;".$text{'allow_all1'}."&gt;" ],
		     map { $_->{'value'} } @targets ],
		   1, 0, !$in{'new'}));

# Allowed IPs (can be v6 or networks)
my $all = $a->{'addrs'}->[0] eq 'ALL' ? 1 : 0;
print &ui_table_row($text{$in{'mode'}.'_ips'},
	&ui_radio("addrs_def", $all,
		  [ [ 1, $text{'allow_all2'} ],
		    [ 0, $text{'allow_below'} ] ])."<br>\n".
	&ui_textarea("addrs", $all ? "" : join("\n", @{$a->{'addrs'}}), 5, 60));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_allow.cgi?mode=$in{'mode'}", $text{'allow_return'});

