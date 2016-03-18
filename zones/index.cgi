#!/usr/local/bin/perl
# Shows all zones, with links to add more

require './zones-lib.pl';
do 'forms-lib.pl';

$p = new WebminUI::Page(undef, $module_info{'desc'}, "intro", 1, 1);
$zn = &get_current_zone();
if (!&has_command("zoneadm")) {
	$p->set_errormsg(&text('index_ecmd', "<tt>zoneadm</tt>"));
	}
elsif ($zn ne "global") {
	$p->set_errormsg(&text('index_eglobal', "<tt>$zn</tt>"));
	}
else {
	# Create the table
	&ReadParse();
	@zones = sort { $a->{'name'} cmp $b->{'name'} } &list_zones();
	$form = new WebminUI::Form();
	$form->set_input(\%in);
	$p->add_form($form);
	$table = new WebminUI::Table([ $text{'list_name'},
                          $text{'list_id'},
                          $text{'list_path'},
                          $text{'list_status'},
                          $text{'list_actions'} ], "100%");
	$form->add_section($table);
	foreach $z (@zones) {
		local ($a, @actions);
		foreach $a (&zone_status_actions($z)) {
			push(@actions, new WebminUI::TableAction("save_zone.cgi", $a->[1], [ [ "zone", $z->{'name'} ], [ $a->[0], 1 ], [ "list", 1 ] ]));
			}
		$table->add_row([
			&ui_link("edit_zone.cgi?zone=$z->{'name'}",$z->{'name'}),
			$z->{'id'},
			$z->{'zonepath'},
			&nice_status($z->{'status'}),
			\@actions
			]);
		}
	$table->set_emptymsg($text{'index_none'});
	$table->add_link("create_form.cgi", $text{'index_add'});
	$p->add_footer("/", $text{'index'});
	}
$p->print();

