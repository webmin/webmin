
require 'dhcpd-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the dhcpd module
sub acl_security_form
{
my ($o) = @_;

foreach my $f ('apply', 'global', 'r_leases', 'w_leases', 'zones') {
	print &ui_table_row($text{'acl_'.$f},
		&ui_yesno_radio($f, $o->{$f}));
	}

print &ui_table_hr();

foreach my $f ('uniq_hst', 'uniq_sub', 'uniq_sha') {
	print &ui_table_row($text{'acl_'.$f},
		&ui_yesno_radio($f, $o->{$f}));
	}

print &ui_table_hr();

print &ui_table_row($text{'acl_seclevel'},
	&ui_radio("smode", defined($o->{'smode'}) ? $o->{'smode'} : 0,
		  [ map { [ $_, $_ ] } 0 .. 3 ]),
	3);

print &ui_table_row($text{'acl_hide'},
	&ui_yesno_radio("hide", defined($o->{'hide'}) ? $o->{'hide'} : 0));

print &ui_table_hr();

foreach my $type (['hst', 'acl_ahst'], ['grp', 'acl_agrp'],
		  ['sub', 'acl_asub'], ['sha', 'acl_asha']) {
	print &ui_table_row($text{$type->[1]},
		join("", map { &ui_checkbox($_."_".$type->[0], 1,
					    $text{"acl_".$_},
					    $o->{$_."_".$type->[0]}) }
			 qw(c r w)),
		3);
	}

print &ui_table_hr();

foreach my $f ('per_sub_acls', 'per_sha_acls',
	       'per_hst_acls', 'per_grp_acls') {
	print &ui_table_row($text{'acl_'.$f},
		&ui_yesno_radio($f, $o->{$f}));
	}

print &ui_table_hr();
print &ui_table_span($text{'acl_per_obj_acls'});
&display_tree($o, &get_parent_config(), -2);
}

# acl_security_save(&options)
# Parse the form for security options for the sendmail module
sub acl_security_save
{
if ($in{'r_sub'} < $in{'w_sub'} || $in{'r_sha'} < $in{'w_sha'} ||
    $in{'r_hst'} < $in{'w_hst'} || $in{'r_grp'} < $in{'w_grp'}) {
	&error($text{'acl_ernow'});
	}
$_[0]->{'apply'}=$in{'apply'};
$_[0]->{'global'}=$in{'global'};
$_[0]->{'r_leases'}=$in{'r_leases'};
$_[0]->{'w_leases'}=$in{'w_leases'};
$_[0]->{'zones'}=$in{'zones'};
$_[0]->{'uniq_hst'}=$in{'uniq_hst'};
$_[0]->{'uniq_sub'}=$in{'uniq_sub'};
$_[0]->{'uniq_sha'}=$in{'uniq_sha'};
$_[0]->{'smode'}=$in{'smode'};
$_[0]->{'hide'}=$in{'hide'};
$_[0]->{'per_hst_acls'}=$in{'per_hst_acls'};
$_[0]->{'per_sub_acls'}=$in{'per_sub_acls'};
$_[0]->{'per_grp_acls'}=$in{'per_grp_acls'};
$_[0]->{'per_sha_acls'}=$in{'per_sha_acls'};
$_[0]->{'c_sub'}=$in{'c_sub'};
$_[0]->{'r_sub'}=$in{'r_sub'};
$_[0]->{'w_sub'}=$in{'w_sub'};
$_[0]->{'c_sha'}=$in{'c_sha'};
$_[0]->{'r_sha'}=$in{'r_sha'};
$_[0]->{'w_sha'}=$in{'w_sha'};
$_[0]->{'c_hst'}=$in{'c_hst'};
$_[0]->{'r_hst'}=$in{'r_hst'};
$_[0]->{'w_hst'}=$in{'w_hst'};
$_[0]->{'c_grp'}=$in{'c_grp'};
$_[0]->{'r_grp'}=$in{'r_grp'};
$_[0]->{'w_grp'}=$in{'w_grp'};

foreach (keys %in) {
	  $_[0]->{$_}=$in{$_} if /^ACL\w\w\w_/;
	  }
}

# perm_to(permissions_string,obj_type,\%access,obj_name)
# check per-object permissions:
# permissions_string= 'rw' 'r' 'w' or you perm_to extend this system
# obj_type= 'sub' for subnets, or  'hst' for hosts.
sub perm_to
{
local $acl=$_[2]->{'ACL'.$_[1].'_'.$_[3]};
foreach (split //,$_[0]) {
    return 0 if index($acl,$_) == -1;
    }
return 1;
}

# link config node names and acl categories
%onames=qw(shared-network sha subnet sub group grp host hst);

# display_tree(\%access,\%config_node,display_padding)
sub display_tree
{
local ($acc, $node, $pad)=@_;
if (defined($node->{'name'})) {
	&display_node($acc,$node,$pad) if exists $onames{$node->{'name'}} ;
	}
$pad+=2;
if($node->{'members'}) {
    # recursevly process this subtree
	foreach (@{$node->{'members'}}) { &display_tree($acc, $_, $pad); }
	}
return 1;
}

# display_node(\%access, \%node, padding)									
sub display_node
{
local($acc,$node,$padding)=@_;
local $name=$node->{'values'}->[0];
if (!$name && $node->{'name'} eq 'group') {
	# Name comes from option domain-name
	local @opts = &find("option", $node->{'members'});
	local ($dn) = grep { $_->{'values'}->[0] eq 'domain-name' } @opts;
	if ($dn) {
		$name = $dn->{'values'}->[1];
		}
	else {
		$name = $node->{'index'};
		}
	}
local $nodetype=$onames{$node->{'name'}};
local $aclname='ACL'.$nodetype.'_'.$name;
if (($nodetype eq 'hst')||($nodetype eq 'sub')||
    ($nodetype eq 'grp')||($nodetype eq 'sha')) {
	my $sel = !$acc->{$aclname} || !&perm_to('r', $nodetype, $acc, $name) ? '' :
		  &perm_to('rw', $nodetype, $acc, $name) ? 'rw' : 'r';
	print &ui_table_row(
		("&nbsp;" x $padding)." ".$node->{'name'}.": <b>".
		&html_escape($name)."</b>",
		&ui_radio($aclname, $sel,
			  [ [ '', $text{'acl_na'} ],
			    [ 'r', $text{'acl_r1'} ],
			    [ 'rw', $text{'acl_rw'} ] ]),
		3);
	}
}

1;