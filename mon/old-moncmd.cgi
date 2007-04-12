#!/usr/local/bin/perl
# moncmd.cgi
# enable the desired hosts/watch/services
#
require'./mon-lib.pl';
&init_config();
&ReadParse();
#
	if( ($in{'user'} && $in{'passwd'}) ){
open (FILE,">data/file");
print FILE "pass=$in{'passwd'}\n";
$server=`uname -n`;
chomp($server);chomp($in{'user'});chomp($in{'passwd'});
if($in{'enable'}){
	print FILE "enable $in{'enable'} $in{$in{'enable'}}\n";
}else{
	print FILE "disable $in{'disable'} $in{$in{'disable'}}\n";
}
close(FILE);
#&enable_action("-a -l $in{'user'} -s $server enable service $in{'service'}",$in{'passwd'});
open (MON, "|/webmin-0.87/mon/moncmd.pl -a -l $in{'user'} -s $server -f /webmin-0.87/mon/data/file 1>/dev/null 2>&1") or die "Cannnot fork: $!";
close (MON); 
&redirect("./monshow.cgi");
	}else{
&header();
print <<EOF;
<center><form action=moncmd.cgi method=post>
<table border><tr $tb><th> $text{'head_monauth'}<br>(If this is incorrect, service/watch/hosts cannot be enabled)</th></tr>
<tr bgcolor=cccccc><td>
<table><tr><td>$text{'head_usr'}</td><td><input type="text" name="user" size=12></td></tr>
<tr><td>$text{'head_pass'}</td><td><input type="password" name="passwd" size=12></td></tr>
<tr bgcolor=cccccc align=center><td colspan=2><input type=submit value="OK"></td></tr>
</table></td></tr>
</table>
EOF
if($in{'enable'}){
	print "<input type=hidden name=enable value=$in{'enable'}>\n";
	print "<input type=hidden name=$in{'enable'} value=\"$in{$in{'enable'}}\">\n";
}else{
	print "<input type=hidden name=disable value=$in{'disable'}>\n";
        print "<input type=hidden name=$in{'disable'} value=\"$in{$in{'disable'}}\">\n";
}
print"</form></center>\n";
	}
