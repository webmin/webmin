#!/usr/local/bin/perl
# edit_serv.cgi
# Edit or create a webmin server

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';
our (%text, %in, %config, %access, $status_error_msg);
&ReadParse();
$access{'edit'} || &error($text{'edit_ecannot'});

my $s;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "");
	my %miniserv;
	&get_miniserv_config(\%miniserv);
	my $ts = &this_server();
	$s = { 'port' => $miniserv{'port'},
	       'type' => $config{'auto_type'} || $ts->{'type'}, };
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "");
	$s = &get_server($in{'id'});
	&can_use_server($s) || &error($text{'edit_ecannot'});
	}

print &ui_form_start("save_serv.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'edit_details'}, undef, 2);

print &ui_table_row($text{'edit_host'},
		    &ui_textbox("host", $s->{'host'}, 60));

if ($in{'new'} || $s->{'port'}) {
	print &ui_table_row($text{'edit_port'},
			    &ui_textbox("port", $s->{'port'}, 5));
	}
else {
	print &ui_table_row($text{'edit_port'},
			    &ui_opt_textbox("port", $s->{'port'}, 5,
					    $text{'edit_portnone'}));
	}

if ($s->{'realhost'}) {
	print &ui_table_row($text{'edit_realhost'},
			    "<tt>$s->{'realhost'}</tt>");
	}

if ($access{'forcetype'}) {
	print &ui_hidden("type", $s->{'type'});
	}
else {
	print &ui_table_row($text{'edit_type'},
	    &ui_select("type", $s->{'type'},
		[ map { [ $_->[0], $_->[1] ] }
		      sort { $a->[1] cmp $b->[1] } &get_server_types() ]));
	}

print &ui_table_row($text{'edit_ssl'},
		    &ui_yesno_radio("ssl", int($s->{'ssl'}))."<br>\n".
		    &ui_checkbox("checkssl", 1, $text{'edit_checkssl'},
				 $s->{'checkssl'}));

print &ui_table_row($text{'edit_desc'},
    $config{'show_ip'} ?
	&ui_textbox("desc", $s->{'desc'}, 40, 0, 40) :
	&ui_opt_textbox("desc", $s->{'desc'}, 40, $text{'edit_desc_def'}));

if ($access{'forcegroup'}) {
	# Cannot change group
	foreach my $g (split(/\t/, $s->{'group'})) {
		print &ui_hidden("group", $g),"\n";
		}
	}
else {
	# Show group checkboxes, with option to add a new one
	my @groups = &unique(map { split(/\t/, $_->{'group'}) }
				 &list_servers());
	my %ingroups = map { $_, 1 } split(/\t/, $s->{'group'});
	my @grid = ( );
	foreach my $g (@groups) {
		push(@grid, &ui_checkbox("group", $g, $g, $ingroups{$g}));
		}
	my $gtable = &ui_grid_table(\@grid, 4);
	$gtable .= $text{'edit_new'}." ".&ui_textbox("newgroup", undef, 10);
	print &ui_table_row($text{'edit_group'}, $gtable, 3);
	}

my $mode = $in{'new'} ? $config{'deflink'} :
	$s->{'autouser'} ? 2 :
	$s->{'sameuser'} ? 3 : $s->{'user'} ? 1 : 0;
if ($access{'forcelink'}) {
	print &ui_hidden("mode", $mode),"\n";
	if ($mode == 1) {
		print &ui_table_row($text{'edit_luser'},
				    &ui_textbox("wuser", $s->{'user'}, 10));
		print &ui_table_row($text{'edit_lpass'},
				    &ui_password("wpass", $s->{'pass'}, 10));
		}
	}
else {
	# Login mode
	my $qulbl = &quote_escape($text{'edit_user'}, '"');
	my $qplbl = &quote_escape($text{'edit_pass'}, '"');
	my $linksel = &ui_radio("mode", $mode,
		[ [ 0, "$text{'edit_mode0'}<br>" ],
		  [ 1, &text('edit_mode12',
			&ui_textbox("wuser", $mode == 1 ? $s->{'user'} : "", 8,
			    undef, undef,
			    " aria-label=\"$qulbl\" placeholder=\"$qulbl\""),
			&ui_password("wpass", $s->{'pass'}, 8, undef, undef,
			    " aria-label=\"$qplbl\" placeholder=\"$qplbl\"")).
			"<br>" ],
		  [ 2, "$text{'edit_mode2'}<br>" ],
		  ($access{'pass'} && !$main::session_id || $mode == 3 ?
		    ( [ 3, "$text{'edit_mode3'}<br>".
			   (defined($main::remote_pass) ? "" :
			    &ui_note($text{'edit_same'})."<br>") ] )
		    : ( ) ) ]);
	print &ui_table_row($text{'edit_link'}, $linksel);
	}

if ($access{'forcefast'}) {
	# Don't allow choosing of fast mode
	print &ui_hidden("fast", $in{'new'} ? $config{'deffast'}
					    : $s->{'fast'});
	}
else {
	if (($in{'new'} && $config{'deffast'} != 1) || $s->{'fast'} == 2) {
		print &ui_table_row($text{'edit_fast'},
			&ui_radio("fast", $config{'deffast'},
				[ [ 1, $text{'yes'} ],
				  [ 2, $text{'edit_auto'} ],
				  [ 0, $text{'no'} ] ]));
		}
	elsif (!$in{'new'} && $s->{'fast'} != 1) {
		print &ui_table_row($text{'edit_fast'},
			&ui_radio("fast", int($s->{'fast'}),
				[ [ 1, $text{'yes'} ],
				  [ 0, $text{'no'} ] ]));
		}
	}

if ($s->{'user'} && $config{'show_status'}) {
	sub status_error
	{
	$status_error_msg = join("", @_);
	}
	my $msg;
	&remote_error_setup(\&status_error);
	eval {
		$SIG{'ALRM'} = sub { die "alarm\n" };
		alarm(10);
		&remote_foreign_require($s, "webmin","webmin-lib.pl");
		if ($status_error_msg) {
			# Failed to connect
			$msg = $status_error_msg;
			}
		else {
			# Connected - get status
			$msg = &text('edit_version',
				&remote_foreign_call($s, "webmin",
						     "get_webmin_version"));
			}
		alarm(0);
		};
	if ($@) {
		$msg = $text{'edit_timeout'};
		}

	print &ui_table_row($text{'edit_status'}, $msg, 3);
	}
print &ui_table_end();
print &ui_form_end([
	[ "save", $text{'save'} ],
	$in{'new'} ? ( ) : ( [ 'delete', $text{'delete'} ] ) ]);

&ui_print_footer("", $text{'index_return'});

