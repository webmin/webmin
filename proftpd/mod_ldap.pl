# mod_ldap.pl
use Data::Dumper;
sub mod_ldap_directives
{
local $rv = [
	[ 'LDAPServer', 0, 4, 'root', 1.15 ],
	[ 'LDAPDoAuth', 0, 4, 'root', 1.15 ],
        [ 'LDAPDNInfo', 0, 4, 'root', 1.15 ],
        [ 'LDAPDoUIDLookups', 0, 4, 'root', 1.15 ],
        [ 'LDAPDoGIDLookups', 0, 4, 'root', 1.15 ],
        [ 'LDAPAuthBinds', 0, 4, 'root', 1.15 ],
        [ 'LDAPDefaultUID', 0, 4, 'root', 1.15 ],
        [ 'LDAPDefaultGID', 0, 4, 'root', 1.15 ],
        [ 'LDAPHomedirOnDemand', 0, 4, 'root', 1.15 ],
        [ 'LDAPNegativeCache', 0, 4, 'root', 1.15 ],
        [ 'LDAPQueryTimeout', 0, 4, 'root', 1.15 ],
        [ 'LDAPDefaultAuthScheme', 0, 4, 'root', 1.15 ],

		];
return &make_directives($rv, $_[0], "mod_ldap");
}

sub edit_LDAPServer {
local ($rv);
my $param = $_[0]->{'value'};
$name="LDAPServerp";
$namep=$name.'_m';
my ($port) =$param =~ /.+:(.+)/;
 (my $serveur,my $port)=$param =~ /([^:]+):?(.*)/;
$rv=sprintf "<b>Server:</b> <input name=LDAPServer size=20 value='%s'>\n",
	 $serveur;
$rv .= sprintf "<b> &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp Port:</b><input type=radio
  name=$namep value=0 %s> %s\n",
		!$port  ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=$namep value=1 %s> \n",
		$port ? "checked" : "" ;
$rv .= sprintf "<input name=$name size=6 value='%s'><br>\n",
		$port ? $port: "";

return (2, "LDAP  Server info",$rv);


}

sub edit_LDAPQueryTimeout {
local ($rv);
my $param = $_[0]->{'value'};
$name="LDAPQueryTimeout";
$namep=$name.'_m';
$rv = sprintf "<input type=radio
  name=$namep value=0 %s> %s\n",
		!$param  ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=$namep value=1 %s> \n",
		$param ? "checked" : "" ;
$rv .= sprintf "<input name=$name size=6 value='%s'><br>\n",
		$param ? $param: "";

return (2, "LDAP  Query timeout",$rv);


}



sub edit_LDAPDoAuth {

local ($rv);
my @tab =@_;
my $name ='LDAPDoAuthp';
my $param = $tab[0]->{'value'};
my $option = $tab[0]->{'words'}->[0];
my $dn = $tab[0]->{'words'}->[1];

$namep=$name.'_m';

$rv = sprintf "<input type=radio  name=$namep value=0 %s> %s\n",
		!$option  ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=$namep value=1 %s> %s\n",
		$option =~/off/i ? "checked" : "" ,"Off";
$rv .= sprintf "<input type=radio name=$namep value=2 %s> %s \n",
		$option =~/on/i ? "checked" : "" ,"On";


$rv .= sprintf "<input name=$name size=40 value='%s'> %s\n",
		$dn ? $dn: "","<b>auth base prefix</b><br>";

return (2,"LDAP Do authentification",$rv);


}
sub edit_LDAPDefaultUID {

local ($rv);
my @tab =@_;
my $name ='LDAPDefaultUID';
my $param = $tab[0]->{'value'};

$rv = sprintf "<input name=$name size=6 value='%s'> %s\n",
		$param ? $param: "","<br>";

return (1,"LDAP Default UID",$rv);


}
sub edit_LDAPHomedirOnDemand {

local ($rv);
my @tab =@_;
my $name ='LDAPHomedirOnDemand';
my $param = $tab[0]->{'value'};

$namep=$name.'_m';

$rv = sprintf "<input type=radio  name=$namep value=0 %s> %s\n",
		!$param  ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=$namep value=1 %s> %s\n",
		$param =~/off/i ? "checked" : "" ,"Off";
$rv .= sprintf "<input type=radio name=$namep value=2 %s> %s \n",
		$param =~/on/i ? "checked" : "" ,"On";

return (1,"LDAP Homedir on demand",$rv);


}
sub edit_LDAPNegativeCache {

local ($rv);
my @tab =@_;
my $name ='LDAPNegativeCache';
my $param = $tab[0]->{'value'};

$namep=$name.'_m';

$rv = sprintf "<input type=radio  name=$namep value=0 %s> %s\n",
		!$param  ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=$namep value=1 %s> %s\n",
		$param =~/off/i ? "checked" : "" ,"Off";
$rv .= sprintf "<input type=radio name=$namep value=2 %s> %s \n",
		$param =~/on/i ? "checked" : "" ,"On";

return (1,"LDAP negative cache",$rv);


}



sub edit_LDAPDefaultGID {

local ($rv);
my @tab =@_;
my $name ='LDAPDefaultGID';
my $param = $tab[0]->{'value'};

$rv = sprintf "<input name=$name size=6 value='%s'> %s\n",
		$param ? $param: "","<br>";

return (1,"LDAP Default GID",$rv);


}

sub edit_LDAPDoUIDLookups {

local ($rv);
my @tab =@_;
my $name ='LDAPDoUIDLookups';
my $param = $tab[0]->{'value'};
my $option = $tab[0]->{'words'}->[0];
my $dn = $tab[0]->{'words'}->[1];

$namep=$name.'_m';

$rv = sprintf "<input type=radio  name=$namep value=0 %s> %s\n",
		!$option  ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=$namep value=1 %s> %s\n",
		$option =~/off/i ? "checked" : "" ,"Off";
$rv .= sprintf "<input type=radio name=$namep value=2 %s> %s \n",
		$option =~/on/i ? "checked" : "" ,"On";


$rv .= sprintf "<input name=$name size=40 value='%s'> %s\n",
		$dn ? $dn: "","<b>uid base prefix</b><br>";

return (2,"LDAP Do UID Lookups",$rv);


}

sub edit_LDAPDoGIDLookups {

local ($rv);
my @tab =@_;
my $name ='LDAPDoGIDLookups';
my $param = $tab[0]->{'value'};
my $option = $tab[0]->{'words'}->[0];
my $dn = $tab[0]->{'words'}->[1];

$namep=$name.'_m';

$rv = sprintf "<input type=radio  name=$namep value=0 %s> %s\n",
		!$option  ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=$namep value=1 %s> %s\n",
		$option =~/off/i ? "checked" : "" ,"Off";
$rv .= sprintf "<input type=radio name=$namep value=2 %s> %s \n",
		$option =~/on/i ? "checked" : "" ,"On";


$rv .= sprintf "<input name=$name size=40 value='%s'> %s\n",
		$dn ? $dn: "","<b>gid base prefix</b><br>";

return (2,"LDAP Do GID Lookups",$rv);


}

#sub edit_LDAPXort {
#local ($rv);
#return (1, "LDAPPort",
#sprintf "<input name=LDAPXPort size=6 value='%s'>\n",
#	 $_[0]->{'value'});
#}


sub edit_LDAPDNInfo {

local ($rv);
#return (2, "LDAPDNinfo",
$rv =sprintf "<b>BindDN:</b><input name=LDAPDNinfodn size=30 value='%s'>\n",
	 $_[0]->{'words'}->[0];
$rv .=sprintf "<b>&nbsp&nbsp&nbsp&nbsp PasswordDN</b><input name=LDAPDNinfopasswd size=20 value='%s'>\n",
	 $_[0]->{'words'}->[1];

return(2,"LDAP DN info",$rv);
}
sub edit_LDAPAuthBinds {
local ($rv);
my @tab =@_;
my $name ='LDAPAuthBinds';
my $option = $tab[0]->{'value'};
#my $dn = $tab[0]->{'words'}->[1];
$rv = sprintf "<br><input type=radio  name=$name value=0 %s> %s\n",
		!$option  ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=$name value=1 %s> %s\n",
		$option =~/off/i ? "checked" : "" ,"Off";
$rv .= sprintf "<input type=radio name=$name value=2 %s> %s \n",
		$option =~/on/i ? "checked" : "" ,"On";


return (2,"LDAP auth bind ",$rv);


}
sub edit_LDAPDefaultAuthScheme {
local ($rv);
my @tab =@_;
my $name ='LDAPDefaultAuthScheme';
my $option = $tab[0]->{'value'};
#my $dn = $tab[0]->{'words'}->[1];
$rv = sprintf "<br><input type=radio  name=$name value=0 %s> %s\n",
		!$option  ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=$name value=1 %s> %s\n",
		$option =~/crypt/i ? "checked" : "" ,"crypt";
$rv .= sprintf "<input type=radio name=$name value=2 %s> %s \n",
		$option =~/clear/i ? "checked" : "" ,"clear";


return (2,"LDAP default auth scheme ",$rv);


}

sub save_LDAPAuthBinds{
my $option =$in{'LDAPAuthBinds'};

return ([ ]) unless $option;

return (['off']) if $option==1;
return (['on']) if $option==2;;
return ([ ]);
}
sub save_LDAPDefaultUID{
my $option =$in{'LDAPDefaultUID'};

return ([ ]) unless $option;

return (["$option"]) if $option;
}
sub save_LDAPDefaultGID{
my $option =$in{'LDAPDefaultGID'};

return ([ ]) unless $option;

return (["$option"]) if $option;
}



sub save_LDAPServer {
my $param =$in{'LDAPServer'};
if (($in{'LDAPServerp_m'} == 1) &&  ($in{'LDAPServerp'})){
$param.=":". $in{'LDAPServerp'};
}
return ( [ $param ] ) if $param;
return ( [ ] ) unless $param;
}
sub save_LDAPQueryTimeout {
my $param =$in{'LDAPQueryTimeout'};
if (($in{'LDAPQueryTimeout_m'} == 1) &&  ($in{'LDAPQueryTimeout'})){
$param= $in{'LDAPQueryTimeout'};
} else {undef $param} ;
return ( [ $param ] ) if $param;
return ( [ ] ) unless $param;
}

sub save_LDAPDNInfo {
my $dn = $in{'LDAPDNinfodn'} ;
my $dnp = $in{'LDAPDNinfopasswd'} ;

return([ "\"$dn\" \"$dnp\""]) if $dn;
return ([ ]) unless $dn;
}
sub save_LDAPDoAuth {


my $option = $in{'LDAPDoAuthp_m'} ;
return ([ ]) unless $option;
return (['off']) if $option==1;
my $dn=$in{'LDAPDoAuthp'}; 
return([ "on \"$dn\""]) if $dn;
return ([ ]);
}
sub save_LDAPHomedirOnDemand {


my $option = $in{'LDAPHomedirOnDemand_m'} ;
return ([ ]) unless $option;
return (['off']) if $option==1;
return(['on']) if  $option==2;

}
sub save_LDAPDefaultAuthScheme {


my $option = $in{'LDAPDefaultAuthScheme'} ;
return ([ ]) unless $option;
return ([ ]) if  $option==0;
return (['"crypt"']) if $option==1;
return(['"clear"']) if  $option==2;

}

sub save_LDAPNegativeCache {


my $option = $in{'LDAPNegativeCache_m'} ;
return ([ ]) unless $option;
return (['off']) if $option==1;
return(['on']) if  $option==2;

}



sub save_LDAPDoUIDLookups {



my $option = $in{'LDAPDoUIDLookups_m'} ;
return ([ ]) unless $option;
return (['off']) if $option==1;
my $dn=$in{'LDAPDoUIDLookups'}; 
return([ "on \"$dn\""]) if $dn;
return ([ ]);
}
sub save_LDAPDoGIDLookups {



my $option = $in{'LDAPDoGIDLookups_m'} ;
return ([ ]) unless $option;
return (['off']) if $option==1;
my $dn=$in{'LDAPDoGIDLookups'}; 
return([ "on \"$dn\""]) if $dn;
return ([ ]);
}

