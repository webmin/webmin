#!/usr/local/bin/perl
# Show all firewall rules

require './ipfilter-lib.pl';
&ReadParse();

# Make sure the ipf command is installed
$cmd = &missing_firewall_commands();
if ($cmd) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(
		&ui_config_link('index_ecmd',
			[ "<tt>$cmd</tt>", undef ]));
	}

# Get the version number
$vout = &backquote_command("$config{'ipf'} -V 2>&1");
if ($vout =~ /IP\s+Filter:\s+v?(\S+)/i) {
	$ipf_version = $1;
	}
open(VERSION, ">$module_config_directory/version");
print VERSION $ipf_version,"\n";
close(VERSION);
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 &help_search_link("ipf", "man", "doc", "google"),
		 undef, undef,
		 &text('index_version', $ipf_version));

# See if enabled at boot
$atboot = &check_firewall_init();

# Get the saved and active rules
$live = &get_live_config();
$rules = &get_config();

if (!-r $config{'ipf_conf'} && @$live) {
	# Offer to save existing rules
	print &text('index_existing', scalar(@$live),
		    "<tt>$config{'ipf_conf'}</tt>"),"<p>\n";
	print &ui_form_start("convert.cgi");
	print "<center>",&ui_submit($text{'index_saveex'}),"<p>\n";
	print &ui_checkbox("atboot", 1, $text{'index_atboot'},
			   $atboot == 2),"\n";
	print "</center>",&ui_form_end(),"<p>\n";

	print "<table border width=100%>\n";
	print "<tr $tb><td><b>$text{'index_headerex'}</b></td></tr>\n";
	print "<tr $cb> <td><pre>";
	foreach $dir ("i", "o") {
		open(OUT, "$config{'ipfstat'} -$dir |");
		while(<OUT>) {
			print &html_escape($_);
			}
		close(OUT);
		}
	print "</pre></td> </tr></table>\n";
	}
elsif (@$rules && !$in{'reset'}) {
	# Show the rules
	print &ui_form_start("edit_rule.cgi");
	local @widths = ( "width=10", "width=5%", "width=10%", undef );
	push(@widths, undef) if ($config{'view_condition'});
	push(@widths, undef) if ($config{'view_comment'});
	push(@widths, "width=5%", "width=5%");
	@links = ( &select_all_link("d", 0),
		   &select_invert_link("d", 0) );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'index_active'},
				  $text{'index_action'},
				  $text{'index_dir'},
			    	  $config{'view_condition'} ?
					( $text{'index_desc'} ) : ( ),
			    	  $config{'view_comment'} ?
					( $text{'index_cmt'} ) : ( ),
			    	  $text{'index_move'},
			    	  $text{'index_radd'} ], 100, 0,
				\@widths);
	foreach $r (@$rules) {
		local ($mover, $adder);
		if ($r eq $rules->[@$rules-1]) {
			$mover .= "<img src=images/gap.gif>";
			}
		else {
			$mover .= "<a href='move.cgi?idx=$r->{'index'}&".
			      	  "down=1'><img src=".
			      	  "images/down.gif border=0></a>";
			}
		if ($r eq $rules->[0]) {
			$mover .= "<img src=images/gap.gif>";
			}
		else {
			$mover .= "<a href='move.cgi?idx=$r->{'index'}&".
			          "up=1'><img src=images/up.gif ".
			          "border=0></a>";
			}
		$adder .= "<a href='edit_rule.cgi?new=1&".
			  "after=$r->{'index'}'>".
			  "<img src=images/after.gif border=0></a>";
		$adder .= "<a href='edit_rule.cgi?new=1&".
			  "before=$r->{'index'}'>".
			  "<img src=images/before.gif border=0></a>";

		local $active = $r->{'active'} ? $text{'yes'} :
                                  "<font color=#ff0000>$text{'no'}</font>";
		$active = &ui_link("edit_rule.cgi?idx=$r->{'index'}", $active);
		local $action = $text{'action_'.$r->{'action'}} ||
                                uc($r->{'action'});
		$action = &ui_link("edit_rule.cgi?idx=$r->{'index'}", $action);
		local $dir = $text{'dir_'.$r->{'dir'}};
		$dir = &ui_link("edit_rule.cgi?idx=$r->{'index'}", $dir);

		print &ui_checked_columns_row(
			[ $active,
			  $action,
			  $dir,
			  $config{'view_condition'} ?
				( &describe_rule($r) ) : ( ),
			  $config{'view_comment'} ?
				( $r->{'cmt'} || "<br>" ) : ( ),
			  $mover,
			  $adder ],
			\@widths, "d", $r->{'index'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);

	# Buttons to delete and add
	print "<table width=100%><tr>\n";
	print "<td align=left>",
	      &ui_submit($text{'index_delete'}, "delsel"),"</td>\n";
	print "<td align=right>",
	      &ui_submit($text{'index_add2'}, "new"),"</td>\n";
	print "</tr></table>\n";
	print &ui_form_end();

	# Show NAT rules
	print &ui_hr();
	$natrules = &get_ipnat_config();
	print &ui_form_start("edit_nat.cgi");
	if (@$natrules) {
		local @widths = ( "width=10", "width=5%", "width=10%", undef );
		push(@widths, undef) if ($config{'view_condition'});
		push(@widths, undef) if ($config{'view_comment'});
		push(@widths, "width=5%", "width=5%");
		print &select_all_link("d", 1),"\n";
		print &select_invert_link("d", 1),"<br>\n";
		print &ui_columns_start([ "",
					  $text{'index_active'},
					  $text{'index_nataction'},
					  $config{'view_condition'} ?
						( $text{'index_natfrom'},
						  $text{'index_natto'} ) : ( ),
					  $config{'view_comment'} ?
						( $text{'index_cmt'} ) : ( ),
					  $text{'index_move'} ], 100, 0,
					\@widths);
		foreach $r (@$natrules) {
			local ($mover, $adder);
			if ($r eq $natrules->[@$natrules-1]) {
				$mover .= "<img src=images/gap.gif>";
				}
			else {
				$mover .= "<a href='natmove.cgi?idx=$r->{'index'}&".
					  "down=1'><img src=".
					  "images/down.gif border=0></a>";
				}
			if ($r eq $natrules->[0]) {
				$mover .= "<img src=images/gap.gif>";
				}
			else {
				$mover .= "<a href='natmove.cgi?idx=$r->{'index'}&".
					  "up=1'><img src=images/up.gif ".
					  "border=0></a>";
				}

			local $active = $r->{'active'} ? $text{'yes'} :
                                       "<font color=#ff0000>$text{'no'}</font>";
			$active = &ui_link("edit_nat.cgi?idx=$r->{'index'}",
					   $active);
			local $action = $text{'action_'.$r->{'action'}} ||
				        uc($r->{'action'});
			$action = &ui_link("edit_nat.cgi?idx=$r->{'index'}",
					   $action);

			print &ui_columns_row(
				[ &ui_checkbox("d", $r->{'index'}, "", 0),
				  $active,
				  $action,
				  $config{'view_condition'} ?
					( &describe_from($r), &describe_to($r) ) : ( ),
				  $config{'view_comment'} ?
					( $r->{'cmt'} || "<br>" ) : ( ),
				  $mover ],
				\@widths);
			}
		print &ui_columns_end();
		print &select_all_link("d", 1),"\n";
		print &select_invert_link("d", 1),"<br>\n";
		print "<table width=100%><tr>\n";
		print "<td align=left>",
		      &ui_submit($text{'index_delete'}, "delsel"),"</td>\n";
		print "<td align=right>",
		      &ui_submit($text{'index_add3'}, "newmap"),"\n",
		      &ui_submit($text{'index_add4'}, "newrdr"),"</td>\n";
		print "</tr></table>\n";
		}
	else {
		print "<b>$text{'index_natnone'}</b><p>\n";
		print "<table width=100%><tr>\n";
		print "<td align=right>",
		      &ui_submit($text{'index_add3'}, "newmap"),"\n",
		      &ui_submit($text{'index_add4'}, "newrdr"),"</td>\n";
		print "</tr></table>\n";
		}
	print &ui_form_end();

	# Show buttons to apply configuration and start at boot
	print &ui_hr();

	print &ui_buttons_start();
	if (&foreign_check("servers")) {
		@servers = &list_cluster_servers();
		}
	print &ui_buttons_row("apply.cgi", $text{'index_apply'},
			      @servers ? $text{'index_applydesc2'}
				       : $text{'index_applydesc'});
	print &ui_buttons_row("unapply.cgi", $text{'index_unapply'},
			      $text{'index_unapplydesc'});
	print &ui_buttons_row("bootup.cgi", $text{'index_boot'},
			      $text{'index_bootdesc'}, undef,
			      &ui_radio("boot", $atboot == 2 ? 1 : 0,
					[ [ 1, $text{'yes'} ],
					  [ 0, $text{'no'} ] ]));
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
	print &ui_form_start("setup.cgi");
	print &ui_hidden("reset", $in{'reset'});
	print "<center><table><tr><td>\n";
	print &ui_oneradio("auto", 0, $text{'index_auto0'}, 1),"<p>\n";
	foreach $a (1 .. 4) {
		print &ui_oneradio("auto", $a, $text{'index_auto'.$a}, 0)," ",
		      &interface_choice("iface".$a, undef, 1),"<p>\n";
		}
	print "</td></tr></table>\n";
	print &ui_submit($text{'index_auto'}),"<p>\n";
	print &ui_checkbox("atboot", 1, $text{'index_atboot'},
			   $atboot == 2),"\n";
	print "</center>",&ui_form_end(),"\n";
	}

&ui_print_footer("/", $text{'index'});

