#!/usr/local/bin/perl
# Show all firewall rules

require './ipfw-lib.pl';
&ReadParse();

# Make sure the ipfw command is installed
if (!&has_command($config{'ipfw'})) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(
		&ui_config_link('index_eipfw',
			[ "<tt>$config{'ipfw'}</tt>", undef ]));
	}

# Make sure ipfw works
$rules = &get_config();
$active = &get_config("$config{'ipfw'} show |", \$out);
if ($?) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(
		&ui_config_link('index_elist',
			[ "<tt>$config{'ipfw'} list</tt>",
			  "<pre>$out</pre>", undef ]));
	}

# Get the version number
if ($config{'version'}) {
	$ipfw_version = $config{'version'};
	}
else {
	$vout = `$config{'ipfw'} 2>&1`;
	$vouth = `$config{'ipfw'} -h 2>&1`;
	if ($vout =~ /preproc/ || $vouth =~ /preproc/) {
		$ipfw_version = 2;
		}
	else {
		$ipfw_version = 1;
		}
	}
open(VERSION, ">$module_config_directory/version");
print VERSION $ipfw_version,"\n";
close(VERSION);
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 &help_search_link("ipfw", "man", "doc", "google"),
		 undef, undef,
		 &text('index_version', $ipfw_version));

# Check for an active firewall that is not managed by this module
if (!@$rules && @$active > 1) {
	# Yes .. offer to convert
	print &text('index_existing', scalar(@$active),
		    "<tt>$ipfw_file</tt>"),"<p>\n";
	print &ui_form_start("convert.cgi");
	print "<center>",&ui_submit($text{'index_saveex'}),"<p>\n";
	print "</center>\n";
	print &ui_form_end();

	print "<table border width=100%>\n";
	print "<tr $tb><td><b>$text{'index_headerex'}</b></td></tr>\n";
	print "<tr $cb> <td><pre>";
	print $out;
	print "</pre></td> </tr></table>\n";
	}
elsif (@$rules && !$in{'reset'}) {
	# Find last editable rule
	if ($rules->[@$rules-1]->{'num'} == 65535 &&
	    @$rules > 1) {
		$lastidx = $rules->[@$rules-2]->{'index'};
		}
	else {
		$lastidx = $rules->[@$rules-1]->{'index'};
		}

	# Build map of active rules
	local %amap = map { int($_->{'num'}), $_ } @$active;

	# Show the rules
	print &ui_form_start("edit_rule.cgi");
	local @widths = ( "width=10", "width=5%", undef );
	push(@widths, undef) if ($config{'view_condition'});
	push(@widths, undef) if ($config{'view_comment'});
	push(@widths, "width=5%", "width=5% nowrap") if ($config{'view_counters'});
	push(@widths, "width=5%", "width=5%");
	@links = ( &select_all_link("d", 0),
		   &select_invert_link("d", 0) );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'index_num'},
				  $text{'index_action'},
			    	  $config{'view_condition'} ?
					( $text{'index_desc'} ) : ( ),
			    	  $config{'view_comment'} ?
					( $text{'index_cmt'} ) : ( ),
			    	  $config{'view_counters'} ?
					( $text{'index_count1'},
					  $text{'index_count2'} ) : ( ),
			    	  $text{'index_move'},
			    	  $text{'index_radd'} ], 100, 0,
				\@widths);
	foreach $r (@$rules) {
		next if ($r->{'other'});	# Not displayable
		local ($mover, $adder);
		$mover = &ui_up_down_arrows(
			"move.cgi?idx=$r->{'index'}&up=1",
			"move.cgi?idx=$r->{'index'}&down=1",
			$r->{'index'} != 0 && $r->{'index'} <= $lastidx,
			$r->{'index'} < $lastidx);
		if ($r->{'index'} <= $lastidx) {
			$adder .= "<a href='edit_rule.cgi?new=1&".
				  "after=$r->{'index'}'>".
				  "<img src=images/after.gif border=0></a>";
			$adder .= "<a href='edit_rule.cgi?new=1&".
				  "before=$r->{'index'}'>".
				  "<img src=images/before.gif border=0></a>";
			}

		local $num = $r->{'num'};
		local $act = ($text{'action_'.&real_action($r->{'action'})} ||
                              uc($r->{'action'})).
			     (defined($r->{'aarg'}) ? " $r->{'aarg'}" : "");
		if ($r->{'index'} <= $lastidx) {
			$num = &ui_link("edit_rule.cgi?idx=$r->{'index'}",$num);
			$act = &ui_link("edit_rule.cgi?idx=$r->{'index'}",$act);
			}
		local $a = $amap{int($r->{'num'})};
		print &ui_checked_columns_row(
			[ $num,
			  $act,
			  $config{'view_condition'} ?
				( &describe_rule($r) ) : ( ),
			  $config{'view_comment'} ?
				( $r->{'cmt'} || "<br>" ) : ( ),
			  $config{'view_counters'} ?
				( $a->{'count1'}, &nice_size($a->{'count2'}) ) : ( ),
			  $mover,
			  $adder ],
			\@widths, "d", $r->{'num'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);

	# Show delete and add buttons
	print "<table width=100%><tr>\n";
	print "<td align=left>",
	      &ui_submit($text{'index_delete'}, "delsel"),"</td>\n";
	print "<td align=right>",
	      &ui_submit($text{'index_add2'}, "new"),"</td>\n";
	print "</tr></table>\n";
	print &ui_form_end();

	# Show buttons to apply configuration and start at boot
	print &ui_hr();

	$atboot = &check_boot();
	print &ui_buttons_start();
	if (&foreign_check("servers")) {
		@servers = &list_cluster_servers();
		}
	print &ui_buttons_row("apply.cgi", $text{'index_apply'},
			      @servers ? $text{'index_applydesc2'}
				       : $text{'index_applydesc'});
	print &ui_buttons_row("unapply.cgi", $text{'index_unapply'},
			      $text{'index_unapplydesc'});
	if ($atboot != -1) {
		print &ui_buttons_row("bootup.cgi", $text{'index_boot'},
				      $text{'index_bootdesc'}, undef,
				      &ui_radio("boot", $atboot ? 1 : 0,
						[ [ 1, $text{'yes'} ],
						  [ 0, $text{'no'} ] ]));
		}
	print &ui_buttons_row("index.cgi", $text{'index_reset'},
			      $text{'index_resetdesc'}, undef,
			      &ui_hidden("reset", 1));
	# Show button for cluster page
	if (&foreign_check("servers")) {
		&foreign_require("servers", "servers-lib.pl");
		@allservers = grep { $_->{'user'} }
				&servers::list_servers();
		}
	if (@allservers) {
		print &ui_buttons_row("cluster.cgi", $text{'index_cluster'},
				      $text{'index_clusterdesc'});
		}
	print &ui_buttons_end();
	}
else {
	# Offer to setup simple firewall
	print &text($in{'reset'} ? 'index_rsetup' : 'index_setup',
		    "<tt>$ipfw_file</tt>"),"<p>\n";
	print "<form action=setup.cgi>\n";
	print &ui_hidden("reset", $in{'reset'});
	print "<center><table><tr><td>\n";
	print "<input type=radio name=auto value=0 checked> ",
	      "$text{'index_auto0'}<p>\n";
	foreach $a (2 .. 4) {
		print "<input type=radio name=auto value=$a> ",
		      "$text{'index_auto'.$a} ",
		      &interface_choice("iface".$a, undef, 1),"<p>\n";
		}
	print "</td></tr></table>\n";
	print "<input type=submit value='$text{'index_auto'}'><p>\n";
	print "<input type=checkbox name=atboot value=1> ",
	      "$text{'index_atboot'}\n";
	print "</center></form>\n";
	}

&ui_print_footer("/", $text{'index'});

