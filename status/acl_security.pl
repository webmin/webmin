
do 'status-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the status module
sub acl_security_form
{
my ($o) = @_;
print &ui_table_row($text{'acl_edit'},
	&ui_yesno_radio("edit", $o->{'edit'}));

print &ui_table_row($text{'acl_sched'},
	&ui_yesno_radio("sched", $o->{'sched'}));

# List each monitor and any supplied services it does not already cover
my @serv = &list_services();
my @provided = &module_dashboard_monitors();
my %controls = &match_dashboard_services(\@serv, \@provided);
my %checked = map { $_->{'id'} => 1 } values(%controls);
my @monitors = sort { $a->{'desc'} cmp $b->{'desc'} }
		    (@serv, grep { !$checked{$_->{'id'}} } @provided);

# Missing limits allow all. Map saved service IDs to their monitors.
my $all = !defined($o->{'dashboard_monitors'}) ||
	  $o->{'dashboard_monitors'} eq '*';
my %saved = map { $_ => 1 } split(/\s+/, $o->{'dashboard_monitors'} || '');
my @selected = grep { my $p = $controls{$_};
		      $saved{$_} || ($p && $saved{$p->{'id'}}) }
		    map { $_->{'id'} } @monitors;

# Disable individual selection while all monitors are allowed
print &ui_table_row($text{'acl_monitors'},
	&ui_radio("all_monitors", $all ? 1 : 0,
		  [ [ 1, $text{'acl_all'} ],
		    [ 0, $text{'acl_selected'} ] ])."<br>".
	&ui_select("monitors", \@selected,
		   [ map { [ $_->{'id'}, $_->{'desc'} ] } @monitors ],
		   6, 1, 0, $all).
	&ui_form_field_state_javascript("all_monitors", [ 0 ], [ ],
					[ "monitors" ]));

# Default action visibility to the existing monitor-edit permission
print &ui_table_row($text{'acl_actions'},
	&ui_yesno_radio("actions", defined($o->{'actions'}) ? $o->{'actions'}
							    : $o->{'edit'}));
}

# acl_security_save(&options, &input)
# Parse the form for security options for the status module
sub acl_security_save
{
my ($o, $input) = @_;
$o->{'edit'} = $input->{'edit'};
$o->{'sched'} = $input->{'sched'};

# Save * for all, space-separated IDs for selected, or empty for none
$o->{'dashboard_monitors'} = $input->{'all_monitors'} eq '1' ? '*' :
	join(' ', split(/\0/, $input->{'monitors'} || ''));
# An absent action choice grants no buttons
$o->{'actions'} = $input->{'actions'} eq '1' ? 1 : 0;
}

