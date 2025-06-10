#!/usr/local/bin/perl
# index.cgi
# Display a list of known services, built from those handled by inetd and
# from the services file

require './inetd-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("inetd", "man", "doc", "howto"));

# Break down into rpc and internet services
$j = 0;
foreach $i (&list_inets()) {
	if ($i->[2]) {
		# rpc service
		$i->[3] =~ /^(\S+)\//;
		if ($i->[1]) { $rpc_active{$1} = $j; }
		else { $rpc_disabled{$1} = $j; }
		}
	else {
		# internet service
		if ($i->[1]) { $int_active{$i->[3],$i->[5]} = $j; }
		else { $int_disabled{$i->[3],$i->[5]} = $j; }
		}
	$j++;
	}

# Get and sort entries from /etc/services
@links = ( "<a href=\"edit_serv.cgi?new=1\">$text{'index_newservice'}</a>" );
$i = 0;
@slist = &list_services();
if ($config{'sort_mode'} == 1) {
	@slist = sort { uc($a->[1]) cmp uc($b->[1]) } @slist;
	}
elsif ($config{'sort_mode'} == 2) {
	@slist = sort { (defined($int_active{$b->[1],$b->[3]}) ? 2 :
			 defined($int_disabled{$b->[1],$b->[3]}) ? 1 : 0) <=>
			(defined($int_active{$a->[1],$a->[3]}) ? 2 :
			 defined($int_disabled{$a->[1],$a->[3]}) ? 1 : 0) }
		      @slist;
	}

# Show search form if too many
if (@slist > $config{'display_max'}) {
	print &ui_form_start("index.cgi");
	print "<b>$text{'index_search'}</b> ",
	      &ui_textbox("search", $in{'search'}, 30)," ",
	      &ui_submit($text{'index_sok'}),"<p>\n";
	print &ui_form_end();
	}

# Apply search
if ($in{'search'}) {
	@slist = grep { $_->[1] =~ /\Q$in{'search'}\E/i } @slist;
	}

if (!@slist) {
	# Nothing found!
	print "<b>$text{'index_none'}</b><p>\n";
	}
elsif (@slist <= $config{'display_max'} || $in{'search'}) {
	# Show services
	@grid = ( );
	foreach $s (@slist) {
		$ia = $int_active{$s->[1],$s->[3]};
		$id = $int_disabled{$s->[1],$s->[3]};
		if ($ia =~ /\d/) { $op = "<b>"; $cl = "</b>"; $ip = $ia; }
		elsif ($id =~ /\d/) { $op = "<i><b>"; $cl = "</b></i>"; $ip = $id; }
		elsif (!$config{'show_empty'}) { next; }
		else { $op = $cl = $ip = ""; }
		push(@grid, $op.
		     "<a href=\"edit_serv.cgi?spos=$s->[5]&ipos=$ip\">".
		       &html_escape($s->[1])."</a> (".&html_escape($s->[3]).")".
		     $cl);
		}
	print &ui_links_row(\@links);
	print &ui_grid_table(\@grid, 4, 100, undef, undef,
			     $text{'index_service'});
	}
else {
	# Too many to show
	print "<b>$text{'index_toomany'}</b><p>\n";
	}
print &ui_links_row(\@links);

if (!$config{'show_empty'}) {
	# If only services with commands are shown, use this form to jump
	# to editing a named service
	print &ui_form_start("edit_serv.cgi");
	print &ui_submit($text{'index_edit'})," ",
	      &ui_textbox("name", undef, 20)," ",
	      &ui_select("proto", "tcp", [ &list_protocols() ]),"\n";
	print &ui_form_end();
	}

print &ui_hr();

# Get and sort RPC services
@links = ( "<a href=\"edit_rpc.cgi?new=1\">$text{'index_newrpc'}</a>" );
$i = 0;
@rlist = &list_rpcs();
if ($config{'sort_mode'} == 1) {
	@rlist = sort { uc($a->[1]) cmp uc($b->[1]) } @rlist;
	}
elsif ($config{'sort_mode'} == 2) {
	@rlist = sort { ($rpc_active{$b->[1]} ? 2 :
			 $rpc_disabled{$b->[1]} ? 1 : 0) <=>
			($rpc_active{$a->[1]} ? 2 :
			 $rpc_disabled{$a->[1]} ? 1 : 0) } @rlist;
	}
@grid = ( );
foreach $r (@rlist) {
	$ra = $rpc_active{$r->[1]};
	$rd = $rpc_disabled{$r->[1]};
	$ranum = $rpc_active{$r->[2]};
	$rdnum = $rpc_disabled{$r->[2]};
	if ($ra =~ /\d/) { $op = "<b>"; $cl = "</b>"; $rp = $ra; }
	elsif ($ranum =~ /\d/) { $op = "<b>"; $cl = "</b>"; $rp = $ranum; }
	elsif ($rd =~ /\d/) { $op = "<i><b>"; $cl = "</b></i>"; $rp = $rd; }
	elsif ($rdnum =~ /\d/) { $op = "<i><b>"; $cl = "</b></i>"; $rp = $rdnum; }
	else { $op = $cl = $rp = ""; }
	push(@grid, $op.
		    "<a href=\"edit_rpc.cgi?rpos=$r->[4]&ipos=$rp\">".
		    &html_escape($r->[1])."</a>".$cl);
	}
print &ui_links_row(\@links);
print &ui_grid_table(\@grid, 4, 100, undef, undef,
		     $text{'index_rpc'});
print &ui_links_row(\@links);

print &ui_hr();
print &ui_buttons_start();

print &ui_buttons_row("restart_inetd.cgi",
	$text{'index_apply'}, $text{'index_applymsg'});

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

