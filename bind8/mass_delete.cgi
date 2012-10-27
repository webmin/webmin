#!/usr/local/bin/perl
# Delete a bunch of zones, after asking for confirmation

require './bind8-lib.pl';
&ReadParse();
$conf = &get_config();

$dparams = join("&", map { "d=".&urlize($_) } split(/\0/, $in{'d'}));
if ($in{'update'}) {
	# Redirect to mass update form
	&redirect("mass_update_form.cgi?".$dparams);
	exit;
	}
elsif ($in{'create'}) {
	# Redirect to mass create form
	&redirect("mass_rcreate_form.cgi?".$dparams);
	exit;
	}
elsif ($in{'rdelete'}) {
	# Redirect to mass record delete form
	&redirect("mass_rdelete_form.cgi?".$dparams);
	exit;
	}

# Get the zones
foreach $d (split(/\0/, $in{'d'})) {
	($zonename, $viewidx) = split(/\s+/, $d);
	$zone = &get_zone_name_or_error($zonename, $viewidx);
	if ($zone->{'viewindex'} ne '') {
		$view = $conf->[$zone->{'viewindex'}];
		$zconf = $view->{'members'}->[$zone->{'index'}];
		}
	else {
		$zconf = $conf->[$zone->{'index'}];
		}
	&can_edit_zone($zconf, $view) ||
		&error($text{'master_edelete'});
	push(@zones, [ $zconf, $view ]);
	push(@znames, $zconf->{'value'});
	}
$access{'ro'} && &error($text{'master_ero'});
$access{'delete'} || &error($text{'master_edeletecannot'});

if (!$in{'confirm'}) {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'massdelete_title'}, "");

	@servers = &list_slave_servers();
	print &ui_confirmation_form("mass_delete.cgi",
		&text('massdelete_rusure', scalar(@zones),
		      join(", ", @znames)),
		[ map { [ "d", $_ ] } split(/\0/, $in{'d'}) ],
		[ [ 'confirm', $text{'massdelete_ok'} ] ],
		@servers && $access{'remote'} ?
			$text{'delete_onslave'}." ".
			&ui_yesno_radio("onslave", 1) : "",
		);

	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Do it!
	&ui_print_unbuffered_header(undef, $text{'massdelete_title'}, "");

	foreach $zi (@zones) {
		$zconf = $zi->[0];
		$view = $zi->[1];
		$type = &find_value("type", $zconf->{'members'});
		print &text('massdelete_zone', $zconf->{'value'}),"<br>\n";

		# delete the records file
		$f = &find("file", $zconf->{'members'});
		if ($f && $type ne 'hint') {
			&delete_records_file($f->{'value'});
			}

		# delete any keys
		&delete_dnssec_key($zconf);

		# remove the zone directive
		&lock_file(&make_chroot($zconf->{'file'}));
		&save_directive($view || &get_config_parent($zconf->{'file'}),
				[ $zconf ], [ ]);
		print $text{'massdelete_done'},"<p>\n";

		# Also delete from slave servers
		if ($in{'onslave'} && $access{'remote'}) {
			$viewname = $view ? $view->{'values'}->[0] : undef;
			print &text('massdelete_slaves',
				    $zconf->{'value'}),"<br>\n";
			@slaveerrs = &delete_on_slaves(
				$zconf->{'value'}, undef, $viewname);
			if (@slaveerrs) {
				print $text{'massdelete_failed'},"<br>\n";
				foreach $s (@slaveerrs) {
					print "$s->[0]->{'host'} : $s->[1]<br>\n";
					}
				print "<p>\n";
				}
			else {
				print $text{'massdelete_done'},"<p>\n";
				}
			}
		}
	&flush_file_lines();
	&unlock_all_files();
	&webmin_log("delete", "zones", scalar(@zones));

	&ui_print_footer("", $text{'index_return'});
	}

