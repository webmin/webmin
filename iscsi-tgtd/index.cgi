#!/usr/local/bin/perl
# Display a list of iSCSI targets

use strict;
use warnings;
require './iscsi-tgtd-lib.pl';
our (%text, %config, $module_name);

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("tgtadm", "man", "doc", "google"));

my $err = &check_config();
if ($err) {
	&ui_print_endpage(
		$err." ".&text('index_clink', "../config.cgi?$module_name"));
	}

# Find and show targets
my $conf = &get_tgtd_config();
my @targets = grep { $_->{'name'} eq 'target' } @$conf;
my @crlinks = ( &ui_link("edit_target.cgi?new=1",$text{'index_add'}) );
if (@targets) {
	unshift(@crlinks, &select_all_link("d"), &select_invert_link("d"));
	print &ui_form_start("delete_targets.cgi");
	print &ui_links_row(\@crlinks);
	my @tds = ( "width=5" );
	print &ui_columns_start([
		"", $text{'index_target'}, $text{'index_lun'},
		$text{'index_size'}, $text{'index_users'},
		], 100, 0, \@tds);
	foreach my $t (@targets) {
		my @luns;
		my $size = 0;
		foreach my $l (&find($t, 'backing-store'),
			       &find($t, 'direct-store')) {
			my $v = $l->{'values'}->[0];
			push(@luns, &mount::device_name($v));
			$size += &get_device_size($v);
			}
		my @users = map { $_->{'values'}->[0] }
				&find($t, "incominguser");
		if (@users > 5) {
			@users = (@users[0 .. 4], "...");
			}
		print &ui_checked_columns_row([
			"<a href='edit_target.cgi?name=".
			  &urlize($t->{'value'})."'>".$t->{'value'}."</a>",
			join(" , ", @luns) || "<i>$text{'index_noluns'}</i>",
			$size ? &nice_size($size) : "",
			join(" , ", @users) || "<i>$text{'index_nousers'}</i>"
			],
			\@tds, "d", $t->{'value'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@crlinks);
	print &ui_form_end([ [ undef, $text{'index_delete'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row(\@crlinks);
	}

print &ui_hr();
print &ui_buttons_start();

# Manual edit button
print &ui_buttons_row("edit_manual.cgi", $text{'index_manual'},
		      $text{'index_manualdesc'});

# Show start/stop/restart buttons
my $pid = &is_tgtd_running();
if ($pid) {
	print &ui_buttons_row("restart.cgi", $text{'index_restart'},
			      $text{'index_restartdesc'});
	print &ui_buttons_row("stop.cgi", $text{'index_stop'},
			      $text{'index_stopdesc'});
	}
else {
	print &ui_buttons_row("start.cgi", $text{'index_start'},
			      $text{'index_startdesc'});
	}

# Show start at boot button
&foreign_require("init");
my $starting = &init::action_status($config{'init_name'});
print &ui_buttons_row("atboot.cgi",
		      $text{'index_atboot'},
		      $text{'index_atbootdesc'},
		      undef,
		      &ui_radio("boot", $starting == 2 ? 1 : 0,
				[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});
