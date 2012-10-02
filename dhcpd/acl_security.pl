
require 'dhcpd-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the dhcpd module
sub acl_security_form
{
print "<tr>\n<td><b>$text{'acl_apply'}</b></td> <td>\n";
printf "<input type=radio name=apply value=1 %s> $text{'yes'}\n",
		$_[0]->{'apply'} ? "checked" : "";
printf "<input type=radio name=apply value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'apply'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_global'}</b></td> <td>\n";
printf "<input type=radio name=global value=1 %s> $text{'yes'}\n",
		$_[0]->{'global'} ? "checked" : "";
printf "<input type=radio name=global value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'global'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_r_leases'}</b></td> <td>\n";
printf "<input type=radio name=r_leases value=1 %s> $text{'yes'}\n",
		$_[0]->{'r_leases'} ? "checked" : "";
printf "<input type=radio name=r_leases value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'r_leases'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_w_leases'}</b></td> <td>\n";
printf "<input type=radio name=w_leases value=1 %s> $text{'yes'}\n",
		$_[0]->{'w_leases'} ? "checked" : "";
printf "<input type=radio name=w_leases value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'w_leases'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_zones'}</b></td> <td>\n";
printf "<input type=radio name=zones value=1 %s> $text{'yes'}\n",
		$_[0]->{'zones'} ? "checked" : "";
printf "<input type=radio name=zones value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'zones'} ? "" : "checked";
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# uniqs
print "<tr>\n<td><b>$text{'acl_uniq_hst'}</b></td> <td>\n";
printf "<input type=radio name=uniq_hst value=1 %s> $text{'yes'}\n",
		$_[0]->{'uniq_hst'} ? "checked" : "";
printf "<input type=radio name=uniq_hst value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'uniq_hst'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_uniq_sub'}</b></td> <td>\n";
printf "<input type=radio name=uniq_sub value=1 %s> $text{'yes'}\n",
		$_[0]->{'uniq_sub'} ? "checked" : "";
printf "<input type=radio name=uniq_sub value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'uniq_sub'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_uniq_sha'}</b></td> <td>\n";
printf "<input type=radio name=uniq_sha value=1 %s> $text{'yes'}\n",
		$_[0]->{'uniq_sha'} ? "checked" : "";
printf "<input type=radio name=uniq_sha value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'uniq_sha'} ? "" : "checked";
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# security mode settings
print "<tr>\n<td><b>$text{'acl_seclevel'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=smode value=0 %s> 0\n",
		$_[0]->{'smode'} == 0 ? "checked" : "";
printf "<input type=radio name=smode value=1 %s> 1\n",
		$_[0]->{'smode'} == 1 ? "checked" : "";
printf "<input type=radio name=smode value=2 %s> 2\n",
		$_[0]->{'smode'} == 2 ? "checked" : "";
printf "<input type=radio name=smode value=3 %s> 3\n",
		$_[0]->{'smode'} == 3 ? "checked" : "";
print "</td>\n</tr>\n";

print "<tr>\n<td><b>$text{'acl_hide'}</b></td> <td>\n";
printf "<input type=radio name=hide value=1 %s> $text{'yes'}\n",
		$_[0]->{'hide'} == 1 ? "checked" : "";
printf "<input type=radio name=hide value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'hide'} == 0 ? "checked" : "";
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# global acls
print "<tr>\n<td><b>$text{'acl_ahst'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=checkbox name=c_hst value=1 %s> %s\n",
		$_[0]->{'c_hst'} ? "checked" : "", $text{"acl_c"};
printf "<input type=checkbox name=r_hst value=1 %s> %s\n",
		$_[0]->{'r_hst'} ? "checked" : "", $text{"acl_r"};
printf "<input type=checkbox name=w_hst value=1 %s> %s\n",
		$_[0]->{'w_hst'} ? "checked" : "", $text{"acl_w"};
print "</td> </tr>\n";

print "<tr>\n<td><b>$text{'acl_agrp'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=checkbox name=c_grp value=1 %s> %s\n",
		$_[0]->{'c_grp'} ? "checked" : "", $text{"acl_c"};
printf "<input type=checkbox name=r_grp value=1 %s> %s\n",
		$_[0]->{'r_grp'} ? "checked" : "", $text{"acl_r"};
printf "<input type=checkbox name=w_grp value=1 %s> %s\n",
		$_[0]->{'w_grp'} ? "checked" : "", $text{"acl_w"};
print "</td> </tr>\n";

print "<tr>\n<td><b>$text{'acl_asub'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=checkbox name=c_sub value=1 %s> %s\n",
		$_[0]->{'c_sub'} ? "checked" : "", $text{"acl_c"};
printf "<input type=checkbox name=r_sub value=1 %s> %s\n",
		$_[0]->{'r_sub'} ? "checked" : "", $text{"acl_r"};
printf "<input type=checkbox name=w_sub value=1 %s> %s\n",
		$_[0]->{'w_sub'} ? "checked" : "", $text{"acl_w"};
print "</td> </tr>\n";

print "<tr>\n<td><b>$text{'acl_asha'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=checkbox name=c_sha value=1 %s> %s\n",
		$_[0]->{'c_sha'} ? "checked" : "", $text{"acl_c"};
printf "<input type=checkbox name=r_sha value=1 %s> %s\n",
		$_[0]->{'r_sha'} ? "checked" : "", $text{"acl_r"};
printf "<input type=checkbox name=w_sha value=1 %s> %s\n",
		$_[0]->{'w_sha'} ? "checked" : "", $text{"acl_w"};
print "</td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# per-subnet and per-host acls
print "<tr><td><b>$text{'acl_per_sub_acls'}</b></td> <td>\n";
printf "<input type=radio name=per_sub_acls value=1 %s> $text{'yes'}\n",
		$_[0]->{'per_sub_acls'} ? "checked" : "";
printf "<input type=radio name=per_sub_acls value=0 %s> $text{'no'}\n",
		$_[0]->{'per_sub_acls'} ? "" : "checked";
print "</td></tr>\n";

print "<tr><td><b>$text{'acl_per_sha_acls'}</b></td> <td>\n";
printf "<input type=radio name=per_sha_acls value=1 %s> $text{'yes'}\n",
		$_[0]->{'per_sha_acls'} ? "checked" : "";
printf "<input type=radio name=per_sha_acls value=0 %s> $text{'no'}\n",
		$_[0]->{'per_sha_acls'} ? "" : "checked";
print "</td></tr>\n";

print "<tr><td><b>$text{'acl_per_hst_acls'}</b></td> <td>\n";
printf "<input type=radio name=per_hst_acls value=1 %s> $text{'yes'}\n",
		$_[0]->{'per_hst_acls'} ? "checked" : "";
printf "<input type=radio name=per_hst_acls value=0 %s> $text{'no'}\n",
		$_[0]->{'per_hst_acls'} ? "" : "checked";
print "</td></tr>\n";

print "<tr><td><b>$text{'acl_per_grp_acls'}</b></td> <td>\n";
printf "<input type=radio name=per_grp_acls value=1 %s> $text{'yes'}\n",
		$_[0]->{'per_grp_acls'} ? "checked" : "";
printf "<input type=radio name=per_grp_acls value=0 %s> $text{'no'}\n",
		$_[0]->{'per_grp_acls'} ? "" : "checked";
print "</td></tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr>\n<td $tb><b>$text{'acl_per_obj_acls'}</b></td></tr> \n";
&display_tree($_[0],&get_parent_config(),-2);
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

print "<tr>\n<td>","&nbsp"x$padding,
	  " $node->{'name'}: <b>$name</b></td>\n";

if (($nodetype eq 'hst')||($nodetype eq 'sub')||
    ($nodetype eq 'grp')||($nodetype eq 'sha')) {
	print "<td colspan=3>\n";
	if($acc->{$aclname}) {
		printf "<input type=radio name=$aclname value='' %s> %s\n",
				!&perm_to('r',$nodetype,$acc,$name) ? 
					"checked" : "", $text{"acl_na"};
		printf "<input type=radio name=$aclname value='r' %s> %s\n",
				&perm_to('r',$nodetype,$acc,$name) && 
				!&perm_to('rw',$nodetype,$acc,$name) ? 
					"checked" : "",$text{"acl_r1"};
		printf "<input type=radio name=$aclname value='rw' %s> %s\n",
				&perm_to('rw',$nodetype,$acc,$name) ? 
					"checked" : "", $text{"acl_rw"};
		}
	else {
		printf "<input type=radio name=$aclname value='' checked> %s\n",
				$text{"acl_na"};
		printf "<input type=radio name=$aclname value='r'> %s\n", 
				$text{"acl_r1"};
		printf "<input type=radio name=$aclname value='rw'> %s\n",
				$text{"acl_rw"};
		}
	print "</td>\n";
	}
print "</tr>\n";		
}

1;