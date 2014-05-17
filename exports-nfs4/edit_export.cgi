#!/usr/bin/perl
# edit_export.cgi
# Allow editing of one export to a client

require './exports-lib.pl';
&ReadParse();
local $via_pfs = 0;
local $nfsv = nfs_max_version("localhost");
my $is_new=$in{'new'} ? 1 : 0;

if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "", "create_export");
	$via_pfs = ($nfsv == 4) ? 1 : 0;
	&list_exports(); # only to retrieve nfsv4_root
	$exp->{"pfs"} = $nfsv4_root;
    }
else {
	&ui_print_header(undef, $text{'edit_title'}, "", "edit_export");
	@exps = &list_exports();
	$exp = $exps[$in{'idx'}];
	%opts = %{$exp->{'options'}};
	}

# WebNFS doesn't exist on Linux
local $linux = ($gconfig{'os_type'} =~ /linux/i) ? 1 : 0;

print qq*
<SCRIPT language="JavaScript">
<!--
function virtual_root(){
    if(document.forms[0].is_pfs.checked==1)
        document.forms[0].pfs_dir.disabled=1;
    else
        document.forms[0].pfs_dir.disabled=0;
}
function selectv4(selected){
    if(selected){
        document.forms[0].pfs_dir.disabled=0;
        document.forms[0].is_pfs.disabled=0;
    }
    else{
        document.forms[0].pfs_dir.disabled=1;
        document.forms[0].is_pfs.disabled=1;
    }
}
function enterbindto(){
    if(document.forms[0].pfs_dir.value==""){
        if('$nfsv4_root' == "")
            alert('$text{'alert_no_nfsv4root'}');
        else
            document.forms[0].pfs_dir.value="$nfsv4_root";
    }
}
window.onload = function() {
   if ($is_new)
        virtual_root();
   maj_flav();
}
function disable_all(){
    document.forms[0].host.disabled=1;
    document.forms[0].netgroup.disabled=1;
    document.forms[0].network.disabled=1;
    document.forms[0].netmask.disabled=1;
    document.forms[0].address.disabled=1;
    document.forms[0].prefix.disabled=1;
}
function everybody_select(){
    disable_all();
}
function hostname_select(){
    disable_all();
    document.forms[0].host.disabled=0;
}
function public_select(){
    disable_all();
}
function netgroup_select(){
    disable_all();
    document.forms[0].netgroup.disabled=0;
}
function network_select(){
    disable_all();
    document.forms[0].network.disabled=0;
    document.forms[0].netmask.disabled=0;
    // Autofill
    if(document.forms[0].network.value==""){
    	document.forms[0].network.value="192.168.0.1";
    	document.forms[0].netmask.value="255.255.255.0";
    }
}
function ipv6_select(){
    disable_all();
    document.forms[0].address.disabled=0;
    document.forms[0].prefix.disabled=0;
}
function maj_flav(){
   lgthR = document.forms[0].selectRight.options.length;
   var str="";
   for(var i=0;i<lgthR;i++){
            text=document.forms[0].selectRight.options[i].value;
	    str+=(text+",");
   }
   document.forms[0].the_flav.value=str;
}
function clickLtoR(){
   lgthL = document.forms[0].selectLeft.options.length;
   for(var i=0;i<lgthL;i++){
        if(document.forms[0].selectLeft.options[i].selected){
            text=document.forms[0].selectLeft.options[i].text;
	    value=document.forms[0].selectLeft.options[i].value;
	    lgth = document.forms[0].selectRight.options.length;
	    document.forms[0].selectRight.options[lgth] = new Option(text,value);
        }
   }
   maj_flav();
}
function clickRtoL(){ 
     lgth = document.forms[0].selectRight.options.length;
     for(var i=0;i<lgth;i++){
        if(document.forms[0].selectRight.options[i].selected){
            document.forms[0].selectRight.options[i] = null;
            i--; lgth = document.forms[0].selectRight.options.length;
        }
     }
     maj_flav();
}
function clickUp(){
    idx=document.forms[0].selectRight.selectedIndex;
    if(idx==0) return;
    
    tmpText=document.forms[0].selectRight.options[idx-1].text;
    tmpValue=document.forms[0].selectRight.options[idx-1].value;
    document.forms[0].selectRight.options[idx-1]=new Option(document.forms[0].selectRight.options[idx].text,document.forms[0].selectRight.options[idx].value);
    document.forms[0].selectRight.options[idx]=new Option(tmpText,tmpValue);
    document.forms[0].selectRight.selectedIndex=idx-1;
    maj_flav();
}
function clickDown(){
    lgth = document.forms[0].selectRight.options.length;
    idx=document.forms[0].selectRight.selectedIndex;
    if(idx>=lgth-1) return;
    
    tmpText=document.forms[0].selectRight.options[idx+1].text;
    tmpValue=document.forms[0].selectRight.options[idx+1].value;
    document.forms[0].selectRight.options[idx+1]=new Option(document.forms[0].selectRight.options[idx].text,document.forms[0].selectRight.options[idx].value);
    document.forms[0].selectRight.options[idx]=new Option(tmpText,tmpValue);
    document.forms[0].selectRight.selectedIndex=idx+1;
    maj_flav();
}
-->
</SCRIPT>*;

#--------------------------------------------------------------------
# Get values for export to
# Mode : 0 = public, 1 = netgroup NIS, 2= IPv4 network, 3= everybody, 
# 4=hostname, 5 = gss, 6= IPv6 address
#---------------------------------------------------------------------

my $h = $exp->{'host'};
# and value for authentication 
local $auth = "", $sec = "";
my $html="";

# parse security flavors list and build html code for "select" component

while ($h =~/^(((gss\/)?(krb5|spkm-3|lipkey))|\sys)([ip]?)(([,:](\S+))|$)/ || $h =~/^gss\/(krb5|spkm-3|lipkey)([ip]?)$/) {
    $auth = $1; # sys, krb5, spkm-3 or lipkey
    $sec=$5; # authentication(""), integrity("i"), privacy("p")
    
    my $to_add=0;
    my $suffix="";
    if($sec eq "i"){ $to_add=1; $suffix=" (i)" }
    elsif($sec eq "p"){ $to_add=2; $suffix=" (p)" }
    if($auth eq "sys"){
        $html.=qq*<OPTION VALUE="0">sys\n*;
    }
    elsif($auth eq "gss/krb5" || $auth eq "krb5"){
       $val=1+$to_add;
       $html.=qq*<OPTION VALUE="$val">kerberos 5$suffix\n*;
    }
    elsif($auth eq "gss/spkm-3" || $auth eq "spkm-3"){
       $val=4+$to_add;
       $html.=qq*<OPTION VALUE="$val">spkm-3$suffix\n*;       
    }
    elsif($auth eq "gss/lipkey" || $auth eq "lipkey"){
       $val=7+$to_add;
       $html.=qq*<OPTION VALUE="$val">lipkey$suffix\n*;       
    }
    $h=$8;
}
if($html eq ""){ # Default is sys
    $html=qq*<OPTION VALUE="0">sys\n*;
}

# parse hosts

if ($h eq "=public") { $mode = 0; }
elsif ($h =~ /^\@(.*)/) { $mode = 1; $netgroup = $1; }
elsif ($h =~ /^(\S+)\/(\S+)$/ && check_ip6address($1)) { $mode = 6; $address = $1; $prefix = $2; }
elsif ($h =~ /^(\S+)\/(\S+)$/) {$mode = 2; $network = $1; $netmask = $2; }
elsif ($h eq "" or $h eq "*") { $mode = 3; }
else { $mode = 4; $host = $h; }


print "<form action=save_export.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=the_flav value='sys'>\n";

#-----------------------------------------------------------------
# Exports details
#-----------------------------------------------------------------
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Choice between NFSv3 or NFSv4 (if system supports NFSv4, else default to NFSv3).
if ($nfsv == 4) {
    print "<tr> <td>",&hlink("<b>$text{'edit_nfs_vers'}</b>","vers"),"</td>\n";
    printf qq*<td colspan=3><input type=radio name=via_pfs value=1 checked onClick="selectv4(true)"> 4\n*;
    printf qq*<input type=radio name=via_pfs value=0 %s onClick="selectv4(false)"> 3 (or lower)</td> </tr>\n*;
} else {
    printf "<tr><td><input type=hidden name=via_pfs value=0></td></tr>\n";
}

# Show 'directory to export' input
print "<tr> <td>",&hlink("<b>$text{'edit_dir'}</b>","dir"),"</td>\n";
print "<td colspan=3><input name=dir size=30 value=\"$exp->{'dir'}\">",
    &file_chooser_button("dir", 1);
    
# Show 'NFSv4 root' checkbox
if ($nfsv == 4) {
   printf qq*<td> <input type=checkbox name=is_pfs %s onClick="virtual_root()"> $text{'edit_ispfs'} </td></tr>\n*,defined($opts{'fsid'}) ? "checked" : "";
}

# Show 'bind to' input only for new export (else, bind is already done...)
if ($in{'new'} && $nfsv==4) {
    print "<tr> <td>$text{'edit_in'}</td>\n";
    print qq*<td><input name=pfs_dir size=30 onclick="enterbindto()"></td> </tr>\n*;
}

# Show active input
print "<tr> <td>",&hlink("<b>$text{'edit_active'}</b>","active"),"</td>\n";
printf "<td colspan=3><input type=checkbox name=active value=1 %s> $text{'yes'}\n",
    $in{'new'} || $exp->{'active'} ? 'checked' : '';

#----------------------------------------------------------------
# Host selection
#----------------------------------------------------------------
print &ui_table_end();
print &ui_table_start($text{'hostsec_host'},'width=100%');

# Everybody (3)
printf "<tr><td><input type=radio name=mode value=3 %s onClick=\"everybody_select()\"> $text{'edit_all'} </td>\n",
	$mode == 3 ? "checked" : "";

# Hostname (4)
printf "<td colspan=2><input type=radio name=mode value=4 %s onClick=\"hostname_select()\"> $text{'edit_host'}\n",
	$mode == 4 ? "checked" : "";
print "<input name=host size=31 value='$host'></td> </tr>\n";

# Public (0)
printf "<tr><td><input type=radio name=mode value=0 %s %s onClick=\"public_select()\"> $text{'edit_webnfs'}</td>\n",
	$mode == 0 ? "checked" : "", $linux ? "disabled" : "";

# Netgroup (1)
printf "<td colspan=2><input type=radio name=mode value=1 %s onClick=\"netgroup_select()\"> $text{'edit_netgroup'}\n",
	$mode == 1 ? "checked" : "";
print "<input name=netgroup size=25 value='$netgroup'></td> </tr>\n";

# IPV4 Network (2)
printf "<tr><td colspan=3><input type=radio name=mode value=2 %s onClick=\"network_select()\"> IPv4 $text{'edit_network'}\n",
	$mode == 2 ? "checked" : "";
print qq*<input name=network size=15 value='$network'>\n*;
print "$text{'edit_netmask'} <input name=netmask size=15 value='$netmask'></td> </tr>\n"; 

# IPV6 Network (6)
printf "<tr><td colspan=3><input type=radio name=mode value=6 %s onClick=\"ipv6_select()\"> IPv6 $text{'edit_address'}\n",
    $mode == 6 ? "checked" : "";
print "<input name=address size=39 value='$address'>\n";
print "$text{'edit_prefix'}<input name=prefix size=2 value='$prefix'></td> </tr>\n";

#----------------------------------------------------------------
# Flavors selection
#----------------------------------------------------------------
print &ui_table_end();
    print qq*<table border width=100% valign="TOP">\n*;
    print "<tr $tb> <td><b>$text{'hostsec_flavors'}</b></td> </tr>\n";
    print "<tr $cb> <td><table>\n";
    
    # Lists and buttons for security flavors selection
    print qq*
    <tr> <td>
    $text{'hostsec_supported'}
    <SELECT NAME="selectLeft" SIZE=4 MULTIPLE>
	    <OPTION VALUE="0">sys
	    <OPTION VALUE="1">kerberos 5
	    <OPTION VALUE="2">kerberos 5 (i)
	    <OPTION VALUE="3">kerberos 5 (p)
	    <OPTION VALUE="4">spkm-3
	    <OPTION VALUE="5">spkm-3 (i)
	    <OPTION VALUE="6">spkm-3 (p)
	    <OPTION VALUE="7">lipkey
	    <OPTION VALUE="8">lipkey (i)
	    <OPTION VALUE="9">lipkey (p)
    </SELECT>
    </td>
    <td> <INPUT TYPE="button" NAME="buttonLtoR" VALUE=">>" onClick="clickLtoR()">
    <INPUT TYPE="button" NAME="buttonRtoL" VALUE="<<" onClick="clickRtoL()"> </td>
    <td>$text{'hostsec_enabled'} 
    <SELECT NAME="selectRight" SIZE=4 MULTIPLE>
	    $html
    </SELECT>
    </td>
    <td> <INPUT TYPE="button" NAME="buttonUp" VALUE="$text{'hostsec_up'}" onClick="clickUp()">
    <INPUT TYPE="button" NAME="buttonDown" VALUE="$text{'hostsec_down'}" onClick="clickDown()"></td>
    <tr>
    *;
    print &ui_table_end();

#-----------------------------------------------------------------
# Exports options
#-----------------------------------------------------------------

print &ui_table_start($text{'edit_security'},'width=100%');

# Show read-only input
print "<tr> <td>",&hlink("<b>$text{'edit_ro'}</b>","ro"),"</td>\n";
printf "<td><input type=checkbox name=ro %s> $text{'yes'}\n",
	defined($opts{'rw'}) ? "" : "checked";

# Show input for secure port
print "<td>",&hlink("<b>$text{'edit_insecure'}</b>","insecure"),"</td>\n";
printf "<td><input type=checkbox name=insecure %s> $text{'yes'}\n",
	defined($opts{'insecure'}) ? "" : "checked";

# Show subtree check input
print "<tr> <td>",&hlink("<b>$text{'edit_subtree_check'}</b>","subtree_check"),"</td>\n";
printf "<td><input type=checkbox name=no_subtree_check%s> $text{'yes'}\n",
    defined($opts{'no_subtree_check'}) ? "checked" : "";

# Show nohide check input
print "<td>",&hlink("<b>$text{'edit_hide'}</b>","hide"),"</td>\n";
printf "<td><input type=checkbox name=nohide %s> $text{'yes'}\n",
	defined($opts{'nohide'}) ? "" : "checked";

# Show sync input
print "<tr> <td>",&hlink("<b>$text{'edit_sync'}</b>","sync"),"</td>\n<td colspan=3>";
printf "<input type=checkbox name=sync %s> %s\n",defined($opts{'async'}) ? "" : "checked", $text{'yes'};
print "</td> </tr>\n";

# Show root trust input
print "<tr> <td>",&hlink("<b>$text{'edit_squash'}</b>","squash"),"</td> <td colspan=3>\n";
printf "<input type=radio name=squash value=0 %s> $text{'edit_everyone'}\n",
	defined($opts{'no_root_squash'}) ? "checked" : "";
printf "<input type=radio name=squash value=1 %s> $text{'edit_except'}\n",
	!defined($opts{'no_root_squash'}) &&
	!defined($opts{'all_squash'}) ? "checked" : "";
printf "<input type=radio name=squash value=2 %s> $text{'edit_nobody'}\n";
	defined($opts{'all_squash'}) ? "checked" : "";
print "</td> </tr>\n";

# Show untrusted user input
print "<tr> <td>",&hlink("<b>$text{'edit_anonuid'}</b>","anonuid"),"</td> <td>\n";
printf "<input type=radio name=anonuid_def value=1 %s> $text{'edit_default'}\n",
    defined($opts{'anonuid'}) ? "" : "checked";
printf "<input type=radio name=anonuid_def value=0 %s>\n",
    defined($opts{'anonuid'}) ? "checked" : "";
printf "<input name=anonuid size=8 value=\"%s\">\n",
    $opts{'anonuid'} ? getpwuid($opts{'anonuid'}) : "";
print &user_chooser_button("anonuid", 0),"</td>\n";

# Show untrusted group input
print "<td>",&hlink("<b>$text{'edit_anongid'}</b>","anongid"),"</td> <td>\n";
printf "<input type=radio name=anongid_def value=1 %s> $text{'edit_default'}\n",
    defined($opts{'anongid'}) ? "" : "checked";
printf "<input type=radio name=anongid_def value=0 %s>\n",
    defined($opts{'anongid'}) ? "checked" : "";
printf "<input name=anongid size=8 value=\"%s\">\n",
    $opts{'anongid'} ? getgrgid($opts{'anongid'}) : "";
print &group_chooser_button("anongid", 0),"</td> </tr>\n";

#-----------------------------------------------------------------
# NFSv2 specific options
#-----------------------------------------------------------------
if ($nfsv < 4) {
    print "<tr $tb> <td colspan=4><b>$text{'edit_v2opts'}</b></td> </tr>\n";
    # Show input for relative symlinks
    print "<tr> <td>",&hlink("<b>$text{'edit_relative'}</b>","link_relative"),"</td>\n";
    printf "<td><input type=radio name=link_relative value=1 %s> $text{'yes'}\n",
	defined($opts{'link_relative'}) ? "checked" : "";
    printf "<input type=radio name=link_relative value=0 %s> $text{'no'}</td>\n",
	defined($opts{'link_relative'}) ? "" : "checked";
    
    # Show deny access input
    print "<td>",&hlink("<b>$text{'edit_noaccess'}</b>","noaccess"),"</td>\n";
    printf "<td><input type=radio name=noaccess value=1 %s> $text{'yes'}\n",
	defined($opts{'noaccess'}) ? "checked" : "";
    printf "<input type=radio name=noaccess value=0 %s> $text{'no'}</td> </tr>\n",
	defined($opts{'noaccess'}) ? "" : "checked";
    
    # Show untrusted UIDs input
    print "<tr> <td>",&hlink("<b>$text{'edit_uids'}</b>","squash_uids"),"</td> <td>\n";
    printf "<input type=radio name=squash_uids_def value=1 %s> $text{'edit_none'}\n",
	$opts{'squash_uids'} ? "" : "checked";
    printf "<input type=radio name=squash_uids_def value=0 %s>\n",
	$opts{'squash_uids'} ? "checked" : "";
    printf "<input name=squash_uids size=15 value=\"%s\"></td>\n",
	$opts{'squash_uids'};
    
    # Show untrusted GIDs input
    print "<td>",&hlink("<b>$text{'edit_gids'}</b>","squash_gids"),"</td> <td>\n";
    printf "<input type=radio name=squash_gids_def value=1 %s> $text{'edit_none'}\n",
	$opts{'squash_gids'} ? "" : "checked";
    printf "<input type=radio name=squash_gids_def value=0 %s>\n",
	$opts{'squash_gids'} ? "checked" : "";
    printf "<input name=squash_gids size=15 value=\"%s\"></td> </tr>\n",
	$opts{'squash_gids'};
}

print &ui_table_end();
if (!$in{'new'}) {
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value=\"$text{'save'}\"></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value=\"$text{'delete'}\"></td>\n";
	print "</tr></table>\n";
	}
else {
	print "<input type=hidden name=new value=1>\n";
	print "<input type=submit value=\"$text{'create'}\">\n";
	}

&ui_print_footer("", $text{'index_return'});
