#!/usr/local/bin/perl
# edit_group.cgi
# Edit or create a webmin group

require './acl-lib.pl';
&ReadParse();
$access{'groups'} || &error($text{'gedit_ecannot'});
if ($in{'group'}) {
	# Editing an existing group
	&ui_print_header(undef, $text{'gedit_title'}, "");
	$g = &get_group($in{'group'});
	$g || &error($text{'gedit_egone'});
	%group = %$g;
	}
else {
	# Creating a new group
	&ui_print_header(undef, $text{'gedit_title2'}, "");
	%group = ( );
	if ($in{'clone'}) {
		# Copy modules from clone
		$g = &get_group($in{'clone'});
		if ($g) {
			$group{'modules'} = $g->{'modules'};
			}
		}
	}

print &ui_form_start("save_group.cgi", "post");
print &ui_hidden("old", $in{'group'});
if ($in{'clone'}) {
	print &ui_hidden("clone", $in{'clone'});
	}
print &ui_hidden_table_start($text{'gedit_rights'}, "width=100%", 2, "rights",
			     1, [ "width=30%" ]);

# Show the group name
print &ui_table_row($text{'gedit_group'},
	&ui_textbox("name", $group{'name'}, 30, 0, undef, "autocomplete=off"));

# Show group description
print &ui_table_row($text{'gedit_desc'},
	&ui_textbox("desc", $group{'desc'}, 60));

# Find and show the parent group
@glist = grep { $_->{'name'} ne $group{'name'} } &list_groups();
@mcan = $access{'gassign'} eq '*' ?
		( ( map { $_->{'name'} } @glist ), '_none' ) :
		split(/\s+/, $access{'gassign'});
map { $gcan{$_}++ } @mcan;
if (@glist && %gcan) {
	@opts = ( );
	if ($gcan{'_none'}) {
		push(@opts, [ undef, "&lt;$text{'edit_none'}&gt;" ]);
		}
	$memg = undef;
	foreach $g (@glist) {
		if (&indexof('@'.$group{'name'}, @{$g->{'members'}}) >= 0) {
			$memg = $g->{'name'};
			}
		next if (!$gcan{$g->{'name'}} && $memg ne $g->{'name'});
		push(@opts, [ $g->{'name'} ]);
		}
	print &ui_table_row($text{'edit_group'},
		&ui_select("group", $memg, \@opts));
	}

if ($in{'group'}) {
	# Show all current members
	@grid = map { $_ =~ /^\@(.*)$/ ? "<a href='edit_group.cgi?group=$1'><i>$1</i></a>" : "<a href='edit_user.cgi?user=$_'>$_</a>" }
		    @{$group{'members'}};
	if (@grid) {
		print &ui_table_row($text{'gedit_members'},
				    &ui_links_row(\@grid));
		}
	}

# Storage type
if ($in{'group'}) {
	print &ui_table_row($text{'edit_proto'},
		$text{'edit_proto_'.$group{'proto'}});
	}

print &ui_hidden_table_end("basic");

# Start of modules section
print &ui_hidden_table_start(@groups ? $text{'edit_modsg'} : $text{'edit_mods'},
			     "width=100%", 2, "mods");

# Show available modules, under categories
@mlist = &list_module_infos();
map { $has{$_}++ } @{$group{'modules'}};
@links = ( &select_all_link("mod", 0, $text{'edit_selall'}),
	   &select_invert_link("mod", 0, $text{'edit_invert'}) );
@cats = &unique(map { $_->{'category'} } @mlist);
&read_file("$config_directory/webmin.catnames", \%catnames);
$grids = "";
foreach $c (sort { $b cmp $a } @cats) {
	@cmlist = grep { $_->{'category'} eq $c } @mlist;
	$grids .= "<b>".($catnames{$c} || $text{'category_'.$c})."</b><br>\n";
	@grid = ( );
	$sw = 0;
	foreach $m (@cmlist) {
		local $md = $m->{'dir'};
		$label = "";
		if ($access{'acl'} && $in{'group'}) {
			# Show link for editing ACL
			$label = sprintf "<a href='edit_acl.cgi?".
					 "mod=%s&%s=%s'>%s</a>\n",
				&urlize($m->{'dir'}),
				"group", &urlize($in{'group'}),
				$m->{'desc'};
			}
		else {
			$label = $m->{'desc'};
			}
		push(@grid, &ui_checkbox("mod", $md, $label,$has{$md}));
		}
	$grids .= &ui_grid_table(\@grid, 2, 100, [ "width=50%", "width=50%" ]);
	}
print &ui_table_row(undef, &ui_links_row(\@links).
                           $grids.
                           &ui_links_row(\@links), 2);
print &ui_hidden_table_end("mods");

# Add global ACL section
if ($access{'acl'} && $in{'group'}) {
	print &ui_hidden_table_start($text{'edit_global'}, "width=100%", 2,
				     "global", 0, [ "width=30%" ]);
	%uaccess = &get_group_module_acl($in{'group'}, "");
	print &ui_hidden("acl_security_form", 1);
	&foreign_require("", "acl_security.pl");
	&foreign_call("", "acl_security_form", \%uaccess);
	print &ui_hidden_table_end("global");
	}

# Generate form end buttons
@buts = ( );
push(@buts, [ undef, $in{'group'} ? $text{'save'} : $text{'create'} ]);
if ($in{'group'}) {
	push(@buts, [ "but_clone", $text{'edit_clone'} ]);
	push(@buts, [ "but_delete", $text{'delete'} ]);
	}
print &ui_form_end(\@buts);

&ui_print_footer("", $text{'index_return'});

