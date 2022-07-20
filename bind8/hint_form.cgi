#!/usr/local/bin/perl
# hint_form.cgi
# Display options for creating a new root zone
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %config);

require './bind8-lib.pl';
$access{'master'} || &error($text{'hcreate_ecannot'});
$access{'ro'} && &error($text{'master_ero'});
&ui_print_header(undef, $text{'hcreate_title'}, "",
		 undef, undef, undef, undef, &restart_links());

my $conf = &get_config();
my @views = &find("view", $conf);
my %view;
my @zones;
foreach my $v (@views) {
	my @vz = &find("zone", $v->{'members'});
	map { $view{$_} = $v } @vz;
	push(@zones, @vz);
	}
push(@zones, &find("zone", $conf));
my $file;
my %hashint;
foreach my $z (@zones) {
	my $tv = &find_value("type", $z->{'members'});
	if ($tv eq 'hint') {
		$file = &find_value("file", $z->{'members'});
		$hashint{$view{$z}}++;
		}
	}

# Form start
print $text{'hcreate_desc'},"<p>\n";
print &ui_form_start("create_hint.cgi", "post");
print &ui_table_start($text{'hcreate_header'}, "width=100%", 4);

# File for root data
print &ui_table_row($text{'hcreate_file'},
	&ui_filebox("file", $file, 40));

# Data source
print &ui_table_row($text{'hcreate_real'},
	&ui_radio("real", $file ? 3 : 1,
		  [ [ 1, $text{'hcreate_down'}."<br>" ],
		    [ 2, $text{'hcreate_webmin'}."<br>" ],
		    [ 3, $text{'hcreate_keep'} ] ]));

# Create in view
@views = grep { &can_edit_view($_) && !$hashint{$_} } @views;
if (@views) {
	my ($defview) = grep { lc($_->{'values'}->[0]) eq
			    lc($config{'default_view'}) } @views;
	print &ui_table_row($text{'mcreate_view'},
		&ui_select("view", $defview ? $defview->{'index'} : undef,
		  [ map { [ $_->{'index'}, $_->{'values'}->[0] ] }
			@views ]), 3);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});

