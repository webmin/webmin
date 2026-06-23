#!/usr/local/bin/perl
# Show an inventory of discovered systemd drop-in override files.

use strict;
use warnings;

require './systemd-lib.pl'; ## no critic

our (%access, %config, %text);

ReadParse();

has_command("systemctl") || error($text{'systemd_esystemctl'});
systemd_can_enter_module() || systemd_acl_error('penter');
$config{'show_dropin_inventory'} || error($text{'dropins_disabled'});

my $can_system = systemd_can_view_system();
my $can_user = systemd_can_view_user_scope();

my @system_units = $can_system ? list_units() : ( );
my %system_units = map { $_->{'name'}, $_ } @system_units;
my @user_units = $can_user ?
	grep { systemd_acl_user_allowed($_->{'user'}) }
	     list_all_user_units() : ( );
my %user_units = map { $_->{'user'}."\t".$_->{'name'}, $_ } @user_units;

my @dropins;
push(@dropins, list_system_dropin_override_files()) if ($can_system);
if ($can_user) {
	foreach my $dropin (list_all_user_dropin_override_files()) {
		next if (!systemd_acl_user_allowed($dropin->{'user'}));
		push(@dropins, $dropin);
		}
	}
@dropins = sort { $a->{'scope'} cmp $b->{'scope'} ||
		  ($a->{'user'} || "") cmp ($b->{'user'} || "") ||
		  $a->{'unit'} cmp $b->{'unit'} ||
		  $a->{'file'} cmp $b->{'file'} } @dropins;

ui_print_header(undef, $text{'dropins_title'}, "", "intro", undef, 1,
		undef, action_links());

print ui_tag('p', $text{'dropins_desc'});
if (!@dropins) {
	print ui_tag('p', $text{'dropins_empty'});
	}
else {
	print_dropin_table(\@dropins, \%system_units, \%user_units);
	}

ui_print_footer("index.cgi", $text{'index_return'});

# print_dropin_table(dropins, system-units, user-units)
# Outputs the discovered drop-in inventory table.
sub print_dropin_table
{
my ($dropins, $system_units, $user_units) = @_;
print ui_columns_start([
	$text{'systemd_name'},
	$text{'dropins_scope'},
	$text{'systemd_owner'},
	$text{'dropins_file'},
	$text{'dropins_actions'},
	]);
foreach my $dropin (@$dropins) {
	print ui_columns_row([
		ui_tag('tt', html_escape($dropin->{'unit'})),
		html_escape(dropin_scope_label($dropin)),
		$dropin->{'scope'} eq 'user' ?
			ui_tag('tt', html_escape($dropin->{'user'})) :
			html_escape("-"),
		ui_tag('tt', html_escape($dropin->{'file'})),
		dropin_action_link($dropin, $system_units, $user_units),
		]);
	}
print ui_columns_end();
}

# dropin_scope_label(dropin)
# Returns a human-readable scope label for a drop-in descriptor.
sub dropin_scope_label
{
my ($dropin) = @_;
return $dropin->{'scope'} eq 'user' ?
	$text{'dropins_scope_user'} : $text{'dropins_scope_system'};
}

# dropin_action_link(dropin, system-units, user-units)
# Returns an edit action when the discovered drop-in belongs to a known unit.
sub dropin_action_link
{
my ($dropin, $system_units, $user_units) = @_;
if ($dropin->{'scope'} eq 'user') {
	my $user = $dropin->{'user'};
	my $unit = $dropin->{'unit'};
	return ui_tag('i', html_escape($text{'dropins_unit_missing'}))
		if (!$user_units->{$user."\t".$unit});
	return ui_tag('i', html_escape($text{'dropins_view_only'}))
		if (!systemd_can_dropin(1, $user));
	my $url = "edit_unit.cgi?scope=user&unituser=".urlize($user).
		  "&name=".urlize($unit)."&dropin=1".
		  dropin_file_arg($dropin);
	return ui_link($url, $text{'dropins_edit'});
	}
my $unit = $dropin->{'unit'};
return ui_tag('i', html_escape($text{'dropins_unit_missing'}))
	if (!$system_units->{$unit});
return ui_tag('i', html_escape($text{'dropins_view_only'}))
	if (!systemd_can_dropin(0));
return ui_link("edit_unit.cgi?name=".urlize($unit)."&dropin=1".
	       dropin_file_arg($dropin),
	       $text{'dropins_edit'});
}

# dropin_file_arg(dropin)
# Returns an exact drop-in file query argument for non-standard drop-ins.
sub dropin_file_arg
{
my ($dropin) = @_;
return "" if ($dropin->{'standard'});
return "&dropfile=".urlize($dropin->{'file'});
}
