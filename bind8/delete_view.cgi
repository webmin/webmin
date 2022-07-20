#!/usr/local/bin/perl
# delete_zone.cgi
# Delete an existing view and all its zones
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text, %in); 

require './bind8-lib.pl';
&ReadParse();
my $parent = &get_config_parent();
my $conf = $parent->{'members'};
my $vconf = $conf->[$in{'index'}];
$access{'views'} || &error($text{'view_ecannot'});

my @zones;
if (!$in{'confirm'}) {
	# Ask the user if he is sure ..
	&ui_print_header(undef, $text{'vdelete_title'}, "");

	# Build input for moving zones to another view
	@zones = &find("zone", $vconf->{'members'});
	my $movefield;
	if (@zones) {
		my @moveopts = ( [ 0, $text{'vdelete_delete'} ],
			      [ 1, $text{'vdelete_root'} ] );
		my @views = &find("view", $conf);
		if (@views > 1) {
			push(@moveopts, [ 2, $text{'vdelete_move'}." ".
				&ui_select("newview", undef,
				   [ map { [ $_->{'index'}, $_->{'value'} ] }
					 grep { $_->{'index'} != $in{'index'} }
					      @views ]) ]);
			}
		$movefield = "<b>$text{'vdelete_newview'}</b> ".
			     &ui_radio("mode", 1, \@moveopts);
		}

	# Show confirm form
	print &ui_confirmation_form("delete_view.cgi",
		&text(@zones ? 'vdelete_mesg' : 'vdelete_mesg2',
		      "<tt>$vconf->{'value'}</tt>"),
		[ [ 'index', $in{'index'} ] ],
		[ [ 'confirm', $text{'view_delete'} ] ],
		$movefield);

	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# deal with the zones in this view
@zones = &find("zone", $vconf->{'members'});
my $dest;
if ($in{'mode'} == 1) {
	# Adding to top level
	$dest = &get_config_parent(&add_to_file());
	}
else {
	# Adding to some other view
	$dest = $conf->[$in{'newview'}];
	}
&lock_file(&make_chroot($dest->{'file'}));
foreach my $z (@zones) {
	my $type = &find_value("type", $z->{'members'});
	next if (!$type || $type eq 'hint');
	if ($in{'mode'} == 0) {
		# Delete the records file, and perhaps journal
		my $f = &find_value("file", $z->{'members'});
		if ($f) {
			&delete_records_file($f->{'value'});
			}
		}
	else {
		# Move to another view or the top level.
		# File may change 
		delete($z->{'file'});
		&save_directive($dest, undef, [ $z ], $in{'mode'} == 2 ? 1 : 0);
		}
	}

# remove the view directive
&lock_file(&make_chroot($vconf->{'file'}));
&save_directive($parent, [ $vconf ], [ ]);
&flush_file_lines();
&unlock_all_files();
&webmin_log("delete", "view", $vconf->{'value'}, \%in);
&redirect("");

