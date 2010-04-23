#!/usr/local/bin/perl
# index.cgi
# Display logging search form

require './webminlog-lib.pl';
&foreign_require("acl", "acl-lib.pl");
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

if (!$gconfig{'log'}) {
	print &text('index_nolog', '/webmin/edit_log.cgi'),"<p>\n";
	}
elsif (!$gconfig{'logfiles'}) {
	print &text('index_nologfiles', '/webmin/edit_log.cgi'),"<p>\n";
	}

print &ui_form_start("search.cgi");
print &ui_table_start($text{'index_header'}, undef, 2);

@ulist = sort { $a->{'name'} cmp $b->{'name'} } &acl::list_users();
@canulist = grep { &can_user($_->{'name'}) } @ulist;
if (@canulist == 1) {
	# Can only show one user, so skip this field
	print &ui_hidden("uall", 1),"\n";
	}
else {
	# Show user selectors
	@unames = grep { &can_user($_) } map { $_->{'name'} } @ulist;
	@opts = ( [ 1, $text{'index_uall'}."<br>" ],
		  [ 0, $text{'index_user'}." ".
		       &ui_select("user", undef, \@unames)."<br>" ] );
	if ($access_users{'*'}) {
		push(@opts, [ 2, $text{'index_nuser'}." ".
			         &ui_select("nuser", undef, \@unames)."<br>" ]);
		push(@opts, [ 3, $text{'index_ouser'}." ".
				 &ui_textbox("ouser", undef, 20) ]);
		}
	print &ui_table_row($text{'index_susers'},
			    &ui_radio("uall", 1, \@opts));
	}

# Modules to search
if (&can_mod("global")) {
	push(@mods, [ "global", $text{'index_global'} ]);
	}
foreach $m (sort { $a->{'desc'} cmp $b->{'desc'} } &get_all_module_infos()) {
	next if (!&can_mod($m->{'dir'}));
	$mdir = &module_root_directory($m->{'dir'});
	if (-r "$mdir/log_parser.pl" && &check_os_support($m)) {
		push(@mods, [ $m->{'dir'}, $m->{'desc'} ]);
		}
	}
@opts = ( [ 1, $text{'index_mall'}."<br>" ],
	  [ 0, $text{'index_module'}." ".
	       &ui_select("module", $in{'module'}, \@mods) ] );
print &ui_table_row($text{'index_smods'},
		    &ui_radio("mall", 1, \@opts));

# Dates to search
print &ui_table_row($text{'index_stimes'},
		    &ui_radio("tall", 2,
			[ [ 1, $text{'index_tall'}."<br>" ],
			  [ 2, $text{'index_today'}."<br>" ],
			  [ 3, $text{'index_yesterday'}."<br>" ],
			  [ 4, $text{'index_week'}."<br>" ],
			  [ 0, &text('index_time', &time_input('from'),
						   &time_input('to')) ] ]));

# Search modified files and diff contents
if ($gconfig{'logfiles'}) {
	print &ui_table_row($text{'index_sfile'},
		&ui_radio("fall", 1,
			  [ [ 1, $text{'index_fall'}."<br>" ],
			    [ 0, $text{'index_file'}." ".
				 &ui_textbox("file", undef, 40) ] ]));

	print &ui_table_row($text{'index_sdiff'},
		&ui_radio("dall", 1,
			  [ [ 1, $text{'index_dall'}."<br>" ],
			    [ 0, $text{'index_diff'}." ".
				 &ui_textbox("diff", undef, 40) ] ]));
	}

# Remote host
if ($config{'host_search'}) {
	print &ui_table_row($text{'index_shost'},
		&ui_radio("wall", 1,
			  [ [ 1, $text{'index_wall'}."<br>" ],
			    [ 0, $text{'index_whost'}." ".
				 &ui_textbox("webmin", undef, 30) ] ]));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'index_search'} ] ]);

&ui_print_footer("/", $text{'index'});

sub time_input
{
local $rv = "<input name=$_[0]_d size=2>/";
$rv .= "<select name=$_[0]_m>";
for($i=0; $i<12; $i++) {
	$rv .= "<option value=$i>".$text{"smonth_".($i+1)}."\n";
	}
$rv .= "</select>/<input name=$_[0]_y size=4>";
$rv .= " ".&date_chooser_button("$_[0]_d", "$_[0]_m", "$_[0]_y");
return $rv;
}

