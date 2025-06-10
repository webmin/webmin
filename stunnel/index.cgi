#!/usr/local/bin/perl
# index.cgi
# Display all existing SSL tunnels

require './stunnel-lib.pl';

# Check if stunnel is installed
if (!-x $config{'stunnel_path'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	print &text('index_estunnel', "<tt>$config{'stunnel_path'}</tt>",
		    "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Check if inetd or xinetd is installed
if (!$has_inetd && !$has_xinetd) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	print "$text{'index_einetd'}<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Get the version
$ver = &get_stunnel_version(\$out);
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("stunnel", "man", "doc"), undef, undef,
	&text('index_version', $ver));
#if ($ver >= 4) {
#	print "<p>",&text('index_eversion', $ver, 4.0),"<p>\n";
#	print &ui_hr();
#	&ui_print_footer("/", $text{'index'});
#	exit;
#	}

# List all tunnels currently setup in inetd
$hasconfig = 1;
@tunnels = &list_stunnels();
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   &ui_link("edit_stunnel.cgi?new=1",$text{'index_add'}) );
if (@tunnels) {
	print &ui_form_start("delete_tunnels.cgi", "post");
	@tds = ( "width=5" );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'index_name'},
				  $text{'index_port'},
				  $text{'index_active'},
				  $text{'index_action'} ], 100, 0, \@tds); 
	foreach $t (@tunnels) {
		local @cols;
		if ($ver > 4) {
			# Parse new-style stunnel config file
			if ($t->{'args'} =~ /^(\S+)\s+(\S+)/) {
				$cfile = $2;
				@conf = &get_stunnel_config($cfile);
				($conf) = grep { !$_->{'name'} } @conf;
				}
			}
		if ($ver > 4 && !$cfile) {
			push(@cols, &html_escape($t->{'name'}));
			}
		else {
			push(@cols,
			    &ui_link("edit_stunnel.cgi?idx=$t->{'index'}",&html_escape($t->{'name'})));
			}
		push(@cols, &html_escape($t->{'port'}));
		push(@cols, $t->{'active'} ? $text{'yes'} :
			"<font color=#ff0000>$text{'no'}</font>");
		if ($ver > 4) {
			# Parse new-style stunnel config file
			if ($exec = $conf->{'values'}->{'exec'}) {
				$args = $conf->{'values'}->{'execargs'};
				push(@cols, &text('index_cmd',
				   $args ? "<tt>".&html_escape($args)."</tt>"
				         : "<tt>".&html_escape($exec)."</tt>"));
				}
			elsif ($conn = $conf->{'values'}->{'connect'}) {
				push(@cols, &text('index_remote',
				    "<tt>".&html_escape($conn)."</tt>"));
				}
			elsif ($cfile) {
				push(@cols, &text('index_conf',
					"<tt>$cfile</tt>"));
				}
			else {
				push(@cols, $text{'index_noconf'});
				}
			}
		else {
			# Parse old-style stunnel args
			if ($t->{'args'} =~ /\s*-([lL])\s+(\S+)\s+--\s+(.*)/ ||
			    $t->{'args'} =~ /\s*-([lL])\s+(\S+)/) {
				push(@cols, &text('index_cmd',
				    $3 ? "<tt>".&html_escape($3)."</tt>"
				       : "<tt>".&html_escape($2)."</tt>"));
				}
			elsif ($t->{'args'} =~ /-r\s+(\S+):(\d+)/) {
				push(@cols, &text('index_remote',
				    "<tt>".&html_escape("$1:$2")."</tt>"));
				}
			elsif ($t->{'args'} =~ /-r\s+(\d+)/) {
				push(@cols, &text('index_rport',
				    "<tt>".&html_escape($1)."</tt>"));
				}
			else {
				push(@cols,
				    "<tt>".&html_escape($t->{'args'})."</tt>");
				}
			}
		print &ui_checked_columns_row(\@cols, \@tds, "d",$t->{'index'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
    $hasconfig = 0;
	}

if ( $hasconfig ) {
    my $xmsg = "";
    if ($has_inetd && $has_xinetd) {
	    $xmsg .= $text{'index_applymsg1'};
    } elsif ($has_inetd) {
	    $xmsg .= $text{'index_applymsg2'};
    } else {
	    $xmsg .= $text{'index_applymsg3'};
    }
    print &ui_hr();
    print &ui_buttons_start();
    print &ui_buttons_row("apply.cgi",
        $text{'index_apply'}, $xmsg);
    print &ui_buttons_end();
}

&ui_print_footer("/", $text{'index'});

