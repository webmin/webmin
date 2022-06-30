#!/usr/local/bin/perl
# edit_group.cgi
# Edit or create a webmin group

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access, $config_directory);
&ReadParse();
$access{'groups'} || &error($text{'gedit_ecannot'});
my $g;
my %group;
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
my @glist = grep { $_->{'name'} ne $group{'name'} } &list_groups();
my @mcan = $access{'gassign'} eq '*' ?
		( ( map { $_->{'name'} } @glist ), '_none' ) :
		split(/\s+/, $access{'gassign'});
my %gcan = map { $_, 1 } @mcan;
if (@glist && %gcan) {
	my @opts = ( );
	if ($gcan{'_none'}) {
		push(@opts, [ undef, "&lt;$text{'edit_none'}&gt;" ]);
		}
	my $memg = undef;
	foreach my $g (@glist) {
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
	my @grid = map { $_ =~ /^\@(.*)$/ ? ui_link("edit_group.cgi?group=$1", "<i>$1</i>") : ui_link("edit_user.cgi?user=$_", $_) }
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
print &ui_hidden_table_start($text{'edit_mods'}, "width=100%", 2, "mods");

# Show available modules, under categories
my @mlist = &list_module_infos();
my %has = map { $_, 1 } @{$group{'modules'}};
my @links = ( &select_all_link("mod", 0, $text{'edit_selall'}),
	      &select_invert_link("mod", 0, $text{'edit_invert'}) );
my @cats = &unique(map { $_->{'category'} || "" } @mlist);
my %catnames;
&read_file("$config_directory/webmin.catnames", \%catnames);
my $grids = "";
foreach my $c (sort { $b cmp $a } @cats) {
	my @cmlist = grep { $_->{'category'} eq $c } @mlist;
	$grids .= "<b>".($catnames{$c} || $text{'category_'.$c})."</b><br>\n";
	my @grid = ( );
	my $sw = 0;
	foreach my $m (@cmlist) {
		my $md = $m->{'dir'};
		my $label;
		if ($access{'acl'} && $in{'group'}) {
			# Show link for editing ACL
		    	$label = ui_link("edit_acl.cgi?" .
			     "mod=" . urlize($m->{'dir'}) . 
			     "&group=". urlize($in{'group'}),
			     $m->{'desc'}) . "\n";
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
	my %uaccess = &get_group_module_acl($in{'group'}, "");
	print &ui_hidden("acl_security_form", 1);
	&foreign_require("", "acl_security.pl");
	&foreign_call("", "acl_security_form", \%uaccess);
	print &ui_hidden_table_end("global");
	}

# Generate form end buttons
my @buts = ( );
push(@buts, [ undef, $in{'group'} ? $text{'save'} : $text{'create'} ]);
if ($in{'group'}) {
	push(@buts, [ "but_clone", $text{'edit_clone'} ]);
	push(@buts, [ "but_delete", $text{'delete'} ]);
	}
print &ui_form_end(\@buts);

&ui_print_footer("", $text{'index_return'});

