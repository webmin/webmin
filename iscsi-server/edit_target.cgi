#!/usr/local/bin/perl
# Show a form to edit or create a target

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %in);
my $conf = &get_iscsi_config();
&ReadParse();

# Get the target, or create a new one
my $target;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'target_create'}, "");
	$target = { 'num' => &find_free_num($conf, 'target'),
		    'type' => 'target',
		    'flags' => 'rw',
		    'network' => '192.168.1.0/24' };
	}
else {
	$target = &find($conf, "target", $in{'num'});
	$target || &text('target_egone', $in{'num'});
	&ui_print_header(undef, $text{'target_edit'}, "");
	}

# Show editing form
print &ui_form_start("save_target.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("num", $in{'num'});
print &ui_table_start($text{'target_header'}, undef, 2);

# Target name/number
print &ui_table_row($text{'target_name'},
		    $target->{'type'}.$target->{'num'});

# Extent or device to share
my @poss = map { [ $_->{'type'}.$_->{'num'}, &describe_object($_) ] }
	       ( &find($conf, 'extent'), &find($conf, 'device') );
print &ui_table_row($text{'target_export'},
		    &ui_select("export", $target->{'export'}, \@poss, 1, 0,
			       !$in{'new'}));

# Sharing mode
print &ui_table_row($text{'target_flags'},
		    &ui_select("flags", $target->{'flags'},
			       [ [ 'ro', $text{'targets_flags_ro'} ],
				 [ 'rw', $text{'targets_flags_rw'} ] ]));

# Client network
my $all = $target->{'network'} eq 'any' ||
	  $target->{'network'} eq 'all' ||
	  $target->{'network'} =~ /^0(\.0)*\/0$/ ? 1 : 0;
my ($net, $mask) = $all ? ( "", "" ) : split(/\//, $target->{'network'});
print &ui_table_row($text{'target_network'},
		    &ui_radio("network_def", $all,
			[ [ 1, $text{'target_network_all'} ],
			  [ 0, $text{'target_network_net'} ] ])." ".
		    &ui_textbox("network", $net, 15)." / ".
		    &ui_textbox("mask", $mask, 15));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_targets.cgi", $text{'targets_return'});
