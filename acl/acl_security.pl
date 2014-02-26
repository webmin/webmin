
use strict;
use warnings;
do 'acl-lib.pl';
our (%text, %in);

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
my ($o) = @_;

print &ui_table_row($text{'acl_users'},
	&ui_radio("users_def", $o->{'users'} eq '*' ? 1 :
			       $o->{'users'} eq '~' ? 2 : 0,
		  [ [ 1, $text{'acl_uall'} ],
		    [ 2, $text{'acl_uthis'}."<br>" ],
		    [ 0, $text{'acl_usel'} ] ])."<br>\n".
	&ui_select("users", [ split(/\s+/, $o->{'users'}) ],
		   [ (map { $_->{'name'} } &list_users()),
		     (map { [ '_'.$_->{'name'},
			      &text('acl_gr', $_->{'name'}) ] }
			  &list_groups()) ],
		   6, 1));

print &ui_table_row($text{'acl_mods'},
	&ui_radio("mode", $o->{'mode'},
		  [ [ 0, $text{'acl_all'} ],
		    [ 1, $text{'acl_own'}."<br>" ],
		    [ 2, $text{'acl_sel'}."<br>" ] ]).
	&ui_select("mods", [ split(/\s+/, $o->{'mods'}) ],
		   [ map { [ $_->{'dir'}, $_->{'desc'} ] }
			 &list_module_infos() ],
		   6, 1));

foreach my $f (&list_acl_yesno_fields()) {
	print &ui_table_row($text{'acl_'.$f},
		&ui_yesno_radio($f, $o->{$f}));
	}

print &ui_table_hr();

print &ui_table_row($text{'acl_groups'},
	&ui_yesno_radio("groups", $o->{'groups'}));

print &ui_table_row($text{'acl_gassign'},
	&ui_radio("gassign_def", $o->{'gassign'} eq '*' ? 1 : 0,
		  [ [ 1, $text{'acl_gall'} ],
		    [ 0, $text{'acl_gsel'} ] ])."<br>\n".
	&ui_select("gassign", [ split(/\s+/, $o->{'gassign'}) ],
		   [ map { $_->{'name'} } &list_groups() ],
		   6, 1));
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
my ($o) = @_;
if ($in{'users_def'} == 1) {
	$o->{'users'} = '*';
	}
elsif ($in{'users_def'} == 2) {
	$o->{'users'} = '~';
	}
else {
	$o->{'users'} = join(" ", split(/\0/, $in{'users'}));
	}
$o->{'mode'} = $in{'mode'};
$o->{'mods'} = $in{'mode'} == 2 ? join(" ", split(/\0/, $in{'mods'}))
				   : undef;
foreach my $f (&list_acl_yesno_fields()) {
	$o->{$f} = $in{$f};
	}
$o->{'groups'} = $in{'groups'};
$o->{'gassign'} = $in{'gassign_def'} ? '*' :
		     join(" ", split(/\0/, $in{'gassign'}));
}

sub list_acl_yesno_fields
{
return ('create', 'delete', 'rename', 'acl', 'cert', 'others', 'chcert',
	'lang', 'cats', 'theme', 'ips', 'perms', 'sync', 'unix', 'sessions',
	'switch', 'times', 'pass', 'sql');
}
