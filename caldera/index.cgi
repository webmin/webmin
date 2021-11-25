#!/usr/local/bin/perl
# index.cgi
# Webmin index page for Caldera's theme. Contains two frames, with the
# categories and modules always at the top and the CGIs at the bottom

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
$hostname = &get_display_hostname();
$ver = &get_webmin_version();
if ($gconfig{'real_os_type'}) {
	$ostr = "$gconfig{'real_os_type'} $gconfig{'real_os_version'}";
	}
else {
	$ostr = "$gconfig{'os_type'} $gconfig{'os_version'}";
	}

# Find the category with the most modules
foreach $m (&get_available_module_infos(1)) {
	local $c = $m->{'category'} ? $m->{'category'} : 'other';
	$count{$c}++;
	$maxcat = $count{$c} if ($count{$c} > $maxcat);
	}
$rows = 55 + (int(($maxcat-1) / 3)+1)*25;

# Display the frameset
$title = $gconfig{'nohostname'} ? $text{'main_title2'} :
	      &text('main_title', $ver, $hostname, $ostr);
if ($gconfig{'showlogin'}) {
	$title = $remote_user." : ".$title;
	}
&PrintHeader();
print "<!doctype html public \"-//W3C//DTD HTML 3.2 Final//EN\">\n";
print "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\"><title>$title</title></head>\n";
print "<frameset rows='$rows,*' border=0>\n";
$goto = &get_goto_module();
if ($goto) {
	print "<frame scrolling=no noresize src='index_top.cgi?cat=$goto->{'category'}' name=top>\n";
	print "<frame scrolling=auto noresize src='$goto->{'dir'}/' name=body>\n";
	}
else {
	print "<frame scrolling=no noresize src='index_top.cgi' name=top>\n";
	print "<frame scrolling=auto noresize src='index_body.cgi' name=body>\n";
	}
print "</frameset></html>\n";

