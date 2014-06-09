#!/usr/local/bin/perl
# index.cgi
# List all services currently being monitored

$trust_unknown_referers = 1;
require './status-lib.pl';
print "Refresh: $config{'refresh'}\r\n"
	if ($config{'refresh'});
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# If we are using SNMP for notification, make sure the Perl module is installed
if ($config{'snmp_server'}) {
	eval "use Net::SNMP";
	if ($@) {
		eval "use SNMP_Session";
		}
	if ($@) {
		&ui_print_endpage(
		    &ui_config_link('index_esnmp',
			[ "<tt>Net::SNMP</tt>",
			  "../cpan/download.cgi?source=3&cpan=Net::SNMP&mode=2&return=/$module_name/&returndesc=".&urlize($text{'index_return'}),
			  undef ]));
		}
	}

@serv = &list_services();
$mid = int((@serv-1) / 2);
$oldstatus = &read_file($oldstatus_file, \%oldstatus);

if (@serv) {
	&show_button();
	if ($config{'sort_mode'} == 1) {
		@serv = sort { $a->{'desc'} cmp $b->{'desc'} } @serv;
		}
	elsif ($config{'sort_mode'} == 2) {
		@serv = sort { $a->{'remote'} cmp $b->{'remote'} } @serv;
		}
	elsif ($config{'sort_mode'} == 3) {
		@serv = sort { $oldstatus{$a->{'id'}} <=> $oldstatus{$b->{'id'}} } @serv;
		}
	if (!$config{'index_status'} && $oldstatus) {
		local @st = stat("$module_config_directory/oldstatus");
		local $t = localtime($st[9]);
		print &text('index_oldtime', $t),"<br>\n";
		}

	# Show table of defined monitors
	@links = ( );
	if ($access{'edit'}) {
		print &ui_form_start("delete_mons.cgi", "post");
		push(@links, &select_all_link("d", 1),
			     &select_invert_link("d", 1) );
		}
	print &ui_links_row(\@links);
	if ($config{'columns'} == 2) {
		print "<table width=100%><tr>\n";
		print "<td width=50% valign=top>\n";
		&service_table(@serv[0 .. $mid]);
		print "</td> <td width=50% valign=top>\n";
		&service_table(@serv[$mid+1 .. $#serv]) if (@serv > 1);
		print "</td></tr></table>\n";
		}
	else {
		&service_table(@serv);
		}
	print &ui_links_row(\@links);
	if ($access{'edit'}) {
		print &ui_form_end([ [ "delete", $text{'index_delete'} ],
				     [ "refresh", $text{'index_refsel'} ] ]);
		}
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
&show_button();

print &ui_hr();
print &ui_buttons_start();
if ($access{'sched'}) {
	# Open scheduled monitoring form
	print &ui_buttons_row("edit_sched.cgi",
			      $text{'index_sched'},
			      $text{'index_scheddesc'});
	}
if ($access{'edit'}) {
	# Email templates button
	print &ui_buttons_row("list_tmpls.cgi",
			      $text{'index_tmpls'},
			      $text{'index_tmplsdesc'});
	}
if (!$config{'index_status'}) {
	# Refresh now
	print &ui_buttons_row("refresh.cgi",
			      $text{'index_refresh'},
			      $text{'index_refreshdesc'});
	}
print "</tr></table>\n";

&remote_finished();
&ui_print_footer("/", $text{'index'});

sub service_table
{
# Table header
local @tds = $access{'edit'} ? ( "width=5" ) : ( );
print &ui_columns_start([
	$access{'edit'} ? ( "" ) : ( ),
	$text{'index_desc'},
	$text{'index_host'},
	$config{'index_status'} ? ( $text{'index_up'} ) :
	 $oldstatus ? ( $text{'index_last'} ) : ( ),
	], 100, 0, \@tds);

# One row per monitor
foreach $s (@_) {
	local @cols;
	local $esc = &html_escape($s->{'desc'});
	$esc = "<i>$esc</i>" if ($s->{'nosched'} == 1);
	if ($access{'edit'}) {
		push(@cols, &ui_link("edit_mon.cgi?id=$s->{'id'}",$esc));
		}
	else {
		push(@cols, $esc);
		}
	push(@cols, &nice_remotes($s));

	# Work out and show all the up icons
	local @ups;
	if ($config{'index_status'}) {
		# Showing the current status .. first check dependency
		@stats = &service_status($s, 1);
		if ($s->{'depend'}) {
			$ds = &get_service($s->{'depend'});
			if ($ds) {
				@dstats = &service_status($ds, 1);
				if ($dstats[0]->{'up'} != 1) {
					@stats = map { { 'up' => -4 } } @stats;
					}
				}
			}
		@ups = map { $_->{'up'} } @stats;
		@remotes = map { $_->{'remote'} } @stats;
		}
	elsif ($oldstatus) {
		# Getting status from last check
		$stat = &expand_oldstatus($oldstatus{$s->{'id'}});
		@remotes = &expand_remotes($s);
		@ups = map { defined($stat->{$_}) ? ( $stat->{$_} ) : ( ) }
			   @remotes;
		}
	if (!@ups) {
		push(@cols, "");
		}
	else {
		local @icons;
		for(my $i=0; $i<@ups; $i++) {
			$up = $ups[$i];
			$h = $remotes[$i];
			$h = $text{'index_local'} if ($h eq '*');
			push(@icons, "<img src=".&get_status_icon($up).
				     " title='".&html_escape($h)."'>");
			}
		push(@cols, join("", @icons));
		}
	if ($access{'edit'}) {
		print &ui_checked_columns_row(\@cols, \@tds, "d", $s->{'id'});
		}
	else {
		print &ui_columns_row(\@cols, \@tds);
		}
	}
print &ui_columns_end();
}

sub show_button
{
if ($access{'edit'}) {
	print "<form action=edit_mon.cgi>\n";
	print "<input type=submit value='$text{'index_add'}'> ",
	      "<select name=type>\n";
	foreach $h (sort { $a->[1] cmp $b->[1] } &list_handlers()) {
		printf "<option value=%s>%s</option>\n",
			$h->[0], $h->[1] || $h->[0];
		}
	print "</select></form>\n";
	}
}

